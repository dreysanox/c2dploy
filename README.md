Sure! Here’s a cool and engaging README for your GitHub project:

---

# **c2dploy - The CTF Deployment Wizard**

**c2dploy** is your go-to deployment tool for CTF challenges. This script takes care of all the tedious setup, allowing you to focus on creating epic challenges! It automates the creation of a deployable CTF environment, including a custom Docker setup, compiled binaries, and challenge configurations.

Whether you're creating a buffer overflow challenge or a reverse-engineering puzzle, **c2dploy** gets you up and running with minimal effort. Just provide your C file and flag, and let it do the magic.

---

## **Features**

- **Automated Deployment Structure**: Generates a structured directory with both public and private files, ready for CTF deployment.
- **Docker Integration**: Prepares a `Dockerfile`, `docker-compose.yml`, and necessary configurations to deploy the challenge in a containerized environment.
- **ASLR & Security Checks**: Verifies that the system is set up correctly (ASLR disabled) and ensures the C file includes the necessary setup.
- **Flag Handling**: Automatically inserts a flag into the binary or uses a flag file, based on user input.
- **xinetd Service Setup**: Automatically configures `xinetd` for your service, enabling easy access via a custom port.

---

## **Installation**

To get started, clone this repository to your local machine:

```bash
git clone https://github.com/yourusername/c2dploy.git
cd c2dploy
```

Ensure you have **Docker** and **Docker Compose** installed to build and deploy your challenge.

---

## **Usage**

Run the `c2dploy` script with the following syntax:

```bash
./c2dploy <file.c> <flag> [-f]
```

### **Options**:

- **`<file.c>`**: Your C file containing the challenge code.
- **`<flag>`**: The flag you want to use for the challenge (if `-f` is not specified, the flag will be embedded in the binary).
- **`-f`**: Use this flag if you want to treat the flag as a separate file. Without this flag, the script will embed the flag in the compiled binary.

### **Example**:

1. With a separate flag file:

```bash
./c2dploy challenge.c FLAG{this_is_the_flag} -f
```

2. With the flag embedded in the binary:

```bash
./c2dploy challenge.c FLAG{this_is_the_flag}
```

---

## **How It Works**

1. **Directory Structure**: The script creates an output folder with two subdirectories:
   - `public`: Contains the compiled binary and any other publicly accessible files.
   - `private`: Contains Docker configurations, flag files (if applicable), and service setup files.

2. **Compilation**: It compiles the C file with the following flags to disable security features (e.g., stack protector, PIE):
   ```bash
   gcc <file.c> -o <binary_name> -no-pie -fno-stack-protector
   ```

3. **Docker Setup**:
   - The `Dockerfile` is generated dynamically with your challenge's name and flags.
   - `docker-compose.yml` allows for easy container deployment.

4. **xinetd Service**:
   - Configures `xinetd` to run your challenge on the specified port.
   - The `entrypoint.sh` file ensures the environment is correctly initialized.

---

## **Docker Deployment**

Once the challenge files are generated, you can deploy the challenge by navigating to the `private` directory and running the following:

```bash
cd private
./deploy_challenge.sh
```

This will bring up the challenge in a Docker container, listening on the port you specified.

---

## **Example Structure**

Here's what the output directory will look like:

```
my_challenge_deploy/
├── public/
│   └── my_challenge (compiled binary)
└── private/
    ├── Dockerfile
    ├── docker-compose.yml
    ├── deploy_challenge.sh
    ├── entrypoint.sh
    ├── flag.txt
    └── ctf.xinetd
```

---

**Enjoy hacking, and happy CTFing! 🎮💻**

---
