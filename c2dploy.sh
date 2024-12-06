#!/bin/bash

# Check for correct arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [-f] <file.c> <flag>"
    exit 1
fi

# Check for -f flag
FORCE_FLAG=false
if [ "$1" == "-f" ]; then
    FORCE_FLAG=true
    shift
fi

# Variables
CFILE=$1
FLAG=$2
BASENAME=$(basename "$CFILE" .c)
OUTPUT_DIR="${BASENAME}_deploy"
PUBLIC_DIR="${OUTPUT_DIR}/public"
PRIVATE_DIR="${OUTPUT_DIR}/private"
FAKE_FLAG="FLAG{FAKEFLAG}"

# Ask for the deployment port
read -p "Enter the port to deploy the service: " DEPLOY_PORT

# Check if ASLR is disabled
if [ "$(cat /proc/sys/kernel/randomize_va_space)" -ne 0 ]; then
    echo "Error: ASLR is not disabled. Please disable it by executing this command with sudo user:"
    echo "echo 0 | tee /proc/sys/kernel/randomize_va_space"
    exit 3
fi

# Check if the C file contains the required line
REQUIRED_LINE="setvbuf(stdout, NULL, _IONBF, 0);"
if ! grep -q "$REQUIRED_LINE" "$CFILE"; then
    echo "Please set the standard output buffer mode for stdout to unbuffered by including this in your main function:"
    echo "$REQUIRED_LINE"
    exit 4
fi

# Create directory structure
mkdir -p "$PUBLIC_DIR" "$PRIVATE_DIR"

gcc "$CFILE" -o "${PRIVATE_DIR}/${BASENAME}" -no-pie -fno-stack-protector
if [ $? -ne 0 ]; then
	echo "Compilation failed. Exiting."
	exit 5
fi


# Prepare the C file based on the mode
if [ "$FORCE_FLAG" = true ]; then
    echo "$FLAG" > "${PRIVATE_DIR}/flag.txt"
else
    # Modify the C file to include the fake flag
    TEMP_CFILE="${PUBLIC_DIR}/${BASENAME}_modified.c"
    cp "$CFILE" "$TEMP_CFILE"
    sed -i "s/FLAG *= *\".*\";/FLAG = \"$FAKE_FLAG\";/" "$TEMP_CFILE"

    # Compile the modified C file
    gcc "$TEMP_CFILE" -o "${PUBLIC_DIR}/${BASENAME}" -no-pie -fno-stack-protector
    if [ $? -ne 0 ]; then
        echo "Compilation of modified C file failed. Exiting."
        exit 5
    fi
    # No flag file is required in this mode
    echo "Flag embedded in binary as: $FAKE_FLAG"
fi

# Add ctf.xinetd with dynamic port
cat > "${PRIVATE_DIR}/ctf.xinetd" <<EOF
service ctf
{
    disable     = no
    socket_type = stream
    protocol    = tcp
    wait        = no
    user        = root
    type        = UNLISTED
    port        = $DEPLOY_PORT
    bind        = 0.0.0.0
    server      = /chall
    banner_fail = /etc/banner_fail
    # safety options
    per_source  = 10 # maximum instances of this service per source IP address
    rlimit_cpu  = 1 # maximum number of CPU seconds that the service may use
}
EOF

# Add Dockerfile with dynamic binary name
cat > "${PRIVATE_DIR}/Dockerfile" <<EOF
FROM --platform=linux/amd64 ubuntu:22.04

RUN apt update && apt full-upgrade -y && apt install xinetd build-essential -y && apt install libseccomp-dev -y

COPY ./ctf.xinetd /etc/xinetd.d/ctf
COPY ./entrypoint.sh /start.sh
RUN echo "Blocked by ctf_xinetd" > /etc/banner_fail

COPY ./${BASENAME} /chall
RUN chmod +x /start.sh
RUN chmod +x /chall

COPY ./flag.txt /flag.txt

CMD ["/start.sh"]
EOF

# Add docker-compose.yml
cat > "${PRIVATE_DIR}/docker-compose.yml" <<EOF
services:
  ${BASENAME}:
    build: .
    platform: linux/amd64
    restart: on-failure
    ports:
      - "${DEPLOY_PORT}:${DEPLOY_PORT}"
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 400M
EOF

# Placeholder deploy_challenge.sh
cat > "${PRIVATE_DIR}/deploy_challenge.sh" <<'EOF'
#!/bin/sh
docker compose down
docker compose up --build -d
EOF
chmod +x "${PRIVATE_DIR}/deploy_challenge.sh"

# Placeholder entrypoint.sh
cat > "${PRIVATE_DIR}/entrypoint.sh" <<'EOF'
#!/bin/sh

/etc/init.d/xinetd start;
sleep infinity;
EOF
chmod +x "${PRIVATE_DIR}/entrypoint.sh"

# Final message
echo "Deployment structure created in: $OUTPUT_DIR"
echo "Service will be deployed on port: $DEPLOY_PORT"
if [ "$FORCE_FLAG" = false ]; then
    echo "The binary has the fake flag embedded as: $FAKE_FLAG"
fi
