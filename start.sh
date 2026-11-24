#!/bin/sh
# EDDI on Railway: start EDDI on 127.0.0.1:7070 and Caddy on $PORT (login + /healthz).
# Exits non-zero as soon as either process stops, so Railway restarts the service.
set -eu

export EDDI_USERNAME="${EDDI_USERNAME:-admin}"
if [ -z "${EDDI_PASSWORD:-}" ] || [ "${#EDDI_PASSWORD}" -lt 12 ]; then
	echo "eddi-railway: EDDI_PASSWORD must be set (12+ characters). Refusing to start an open server." >&2
	exit 1
fi
if [ -z "${MONGODB_CONNECTIONSTRING:-}" ]; then
	echo "eddi-railway: MONGODB_CONNECTIONSTRING is not set; it should reference the MongoDB service." >&2
	exit 1
fi
if [ -n "${EDDI_VAULT_MASTER_KEY:-}" ] && [ "${#EDDI_VAULT_MASTER_KEY}" -lt 16 ]; then
	echo "eddi-railway: EDDI_VAULT_MASTER_KEY is shorter than 16 characters; EDDI refuses it." >&2
	exit 1
fi

# EDDI has no login of its own without Keycloak. It listens on loopback only and
# Caddy in front of it asks for the generated password, so its own "no auth"
# opt-outs are safe here: nothing reaches EDDI except through that login.
export EDDI_SECURITY_ALLOW_UNAUTHENTICATED=true
export EDDI_MCP_ALLOW_UNAUTHENTICATED=true
export EDDI_SECRETSTORE_ALLOW_UNAUTHENTICATED=true
export QUARKUS_OIDC_TENANT_ENABLED=false
# Requests arrive through Caddy with the public Host header (Railway domain or a
# custom domain). The DNS-rebinding guard is moot behind the login, so accept any
# host; EDDI still refuses cross-site writes by Origin.
export EDDI_SECURITY_UNAUTHENTICATED_ALLOWED_HOSTS='*'
export EDDI_DATASTORE_TYPE="${EDDI_DATASTORE_TYPE:-mongodb}"
export QUARKUS_HTTP_PORT=7070

# Size the JVM to the service: Railway shows the host's CPUs (32+) inside a
# 1 vCPU service, and the image's 75 % heap leaves too little for metaspace at 0.5 GB.
cpus=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
	read -r quota period < /sys/fs/cgroup/cpu.max || true
	if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ]; then
		cpus=$(( (quota + period - 1) / period ))
	fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 8 ] && cpus=8
limit_mb=0
if [ -r /sys/fs/cgroup/memory.max ]; then
	raw=$(cat /sys/fs/cgroup/memory.max)
	[ "$raw" != "max" ] && limit_mb=$((raw / 1048576))
fi
if [ "$limit_mb" -gt 0 ] && [ "$limit_mb" -lt 1200 ]; then
	ratio=${JAVA_MAX_MEM_RATIO_SMALL:-45}
else
	ratio=${JAVA_MAX_MEM_RATIO:-75}
fi
export JAVA_MAX_MEM_RATIO="$ratio"
export CONTAINER_CORE_LIMIT="$cpus"
export GC_MAX_METASPACE_SIZE="${GC_MAX_METASPACE_SIZE:-192}"
# The image's own JAVA_OPTS_APPEND (a runtime value replaces it, so repeat it) plus small-footprint flags.
export JAVA_OPTS_APPEND="-Dquarkus.http.host=127.0.0.1 -Djava.util.logging.manager=org.jboss.logmanager.LogManager -Dfile.encoding=UTF8 -Deddi.docs.path=/deployments/docs -XX:ActiveProcessorCount=${cpus} -XX:ReservedCodeCacheSize=64m -XX:MaxDirectMemorySize=64m -Xss512k -XX:+UseStringDeduplication ${EDDI_JAVA_OPTS_EXTRA:-}"

PASSWORD_HASH=$(caddy hash-password --algorithm bcrypt --bcrypt-cost 10 --plaintext "$EDDI_PASSWORD")
mkdir -p /tmp/caddy

( unset EDDI_PASSWORD; exec /opt/jboss/container/java/run/run-java.sh ) &
app=$!
( unset EDDI_PASSWORD; export EDDI_PASSWORD_HASH="$PASSWORD_HASH" HOME=/tmp/caddy XDG_CONFIG_HOME=/tmp/caddy XDG_DATA_HOME=/tmp/caddy GOMEMLIMIT="${GOMEMLIMIT:-40MiB}" GOMAXPROCS="$cpus"
  exec caddy run --adapter caddyfile --config /etc/eddi-railway/Caddyfile ) &
proxy=$!
unset PASSWORD_HASH

stopping=0
term() {
	stopping=1
	kill -TERM "$app" "$proxy" 2>/dev/null || true
}
trap term TERM INT

echo "eddi-railway: EDDI 6.7.1 starting (cpus ${cpus}, memory limit ${limit_mb} MB, heap ${ratio}% of it); login user '${EDDI_USERNAME}'"
while kill -0 "$app" 2>/dev/null && kill -0 "$proxy" 2>/dev/null; do
	sleep 2 &
	wait $! || true
done

kill -TERM "$app" "$proxy" 2>/dev/null || true
wait "$app" 2>/dev/null || true
wait "$proxy" 2>/dev/null || true
if [ "$stopping" = 1 ]; then
	exit 0
fi
echo "eddi-railway: a process stopped unexpectedly; exiting 1 so Railway restarts the service" >&2
exit 1
