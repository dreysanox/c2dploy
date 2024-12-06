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
read -p "[+] Enter the port to deploy the service: " DEPLOY_PORT

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

# ________________________________________________________________ Compilation Flags _______________________________________________________

# Display menu and collect choices
echo "[+] Select protections to deactivate (enter numbers separated by spaces, e.g., '1 3 6'):"
echo "	1) Canary"
echo "	2) NX Support"
echo "	3) PIE Support"
echo "	4) No RPATH"
echo "	5) No RUNPATH"
echo "	6) Partial RelRO"
echo "	7) Full RelRO"
echo "	8) Disable All Protections"
echo "	9) Keep All Protections (default)"
read -p " -> Enter your choices: " choices
echo " "

# Set default protections
CANARY="Yes"
NX="Yes"
PIE="Yes"
RPATH="Yes"
RUNPATH="Yes"
RELRO="Partial"

# Update protections based on user input
if [[ -n "$choices" ]]; then
    for choice in $choices; do
        case $choice in
            1) CANARY="No";;
            2) NX="No";;
            3) PIE="No";;
            4) RPATH="No";;
            5) RUNPATH="No";;
            6) RELRO="Partial";;
            7) RELRO="No";;
            8)  # Disable all protections
                CANARY="No"
                NX="No"
                PIE="No"
                RPATH="No"
                RUNPATH="No"
                RELRO="No"
                ;;
            9) break;;  # Keep all protections
            *) echo "Invalid choice: $choice";;
        esac
    done
fi

# Show final protection states
echo "[+] Final protection states:"
echo "	Canary:                 $CANARY"
echo "	NX Support:             $NX"
echo "	PIE Support:            $PIE"
echo "	No RPATH:               $RPATH"
echo "	No RUNPATH:             $RUNPATH"
echo "	RelRO (Partial/Full):   $RELRO"
echo " "
echo " "

# Determine flags based on selections
CFLAGS=""
[ "$CANARY" == "No" ] && CFLAGS="$CFLAGS -fno-stack-protector"
[ "$NX" == "No" ] && CFLAGS="$CFLAGS -z execstack"
[ "$PIE" == "No" ] && CFLAGS="$CFLAGS -no-pie"
[ "$RPATH" == "No" ] && CFLAGS="$CFLAGS -Wl,--disable-new-dtags"
[ "$RUNPATH" == "No" ] && CFLAGS="$CFLAGS -Wl,--disable-new-dtags"
if [ "$RELRO" == "No" ]; then
    CFLAGS="$CFLAGS -Wl,-z,norelro"
elif [ "$RELRO" == "Partial" ]; then
    CFLAGS="$CFLAGS -Wl,-z,relro"
else
    CFLAGS="$CFLAGS -Wl,-z,relro -Wl,-z,now"
fi

#__________________________________________________________________________________________________________________



# Prepare the C file based on the mode
if [ "$FORCE_FLAG" = true ]; then
    # Compile the source file
    gcc "$CFILE" -o "${OUTPUT_DIR}/${BASENAME}" $CFLAGS
    if [ $? -ne 0 ]; then
	echo "Compilation failed. Exiting."
	exit 5
    fi
    echo "$FLAG" > "${PRIVATE_DIR}/flag.txt"
else

    sed -i "s/FLAG *= *\".*\";/FLAG = \"$FLAG\";/" "$CFILE"
    gcc "$CFILE" -o "${PRIVATE_DIR}/${BASENAME}" $CFLAGS
    if [ $? -ne 0 ]; then
	echo "Compilation failed. Exiting."
	exit 5
    fi


    # Modify the C file to include the fake flag
    TEMP_CFILE="${PUBLIC_DIR}/${BASENAME}_modified.c"
    cp "$CFILE" "$TEMP_CFILE"
    sed -i "s/FLAG *= *\".*\";/FLAG = \"$FAKE_FLAG\";/" "$TEMP_CFILE"

    # Compile the modified C file
    gcc "$TEMP_CFILE" -o "${PUBLIC_DIR}/${BASENAME}" $CFLAGS
    if [ $? -ne 0 ]; then
        echo "Compilation of modified C file failed. Exiting."
        exit 5
    fi
    # No flag file is required in this mode
    echo "[+] Fake flag embedded in binary as: $FAKE_FLAG in ${PUBLIC_DIR}/${BASENAME}"
    echo " "
    echo "[+] Flag embedded in binary as: $FLAG in ${PRIVATE_DIR}/${BASENAME}"
    echo " "
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

echo "Zipping: "
zip -r ${OUTPUT_DIR}/${BASENAME} ${PRIVATE_DIR}
echo " "

echo "[+] Docker zip created in ${OUTPUT_DIR}"
echo " "

# Final message
echo "Deployment structure created in: $OUTPUT_DIR"
echo "Service will be deployed on port: $DEPLOY_PORT"

