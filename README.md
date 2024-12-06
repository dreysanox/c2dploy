Sure! Here’s a cool and engaging README for your GitHub project:

---

# **c2dploy - From c file to docker container**

**c2dploy** is script that allows you to go from your c programmed challenge to a docker container in 1 step. 
Whether you're creating a pwn challenge or a reverse-engineering puzzle, **c2dploy** gets you up and running with minimal effort. Just provide your C file and flag, and let it do the magic.

---

## **Features**

- **Handles compilation with protections**: Allows you to choose what protections you want your file to be compiled with.
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

Ensure you have **Docker**, **Docker Compose** and **zip** installed to build and deploy your challenge.

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
./c2dploy -f challenge.c FLAG{this_is_the_flag}
```

2. With the flag embedded in the binary:

```bash
./c2dploy challenge.c FLAG{this_is_the_flag}
```

---

## **How It Works**

**Directory Structure**: The script creates an output folder with two subdirectories:
   - `public`: Contains the compiled binary (in case the flag is in the binary, this binary will be compiled with a fake flag) and any other publicly accessible files.
   - `private`: Contains Docker configurations, flag files (if applicable), and service setup files.


---

## **Example Structure**

Here's what the output directory will look like:


flag in binary:
```
my_challenge_deploy/
├── public/
│   └── my_challenge_fake_flag (compiled binary)
│   └── my_challenge_fake_flag.c
└── private/
    ├── Dockerfile
    ├── docker-compose.yml
    ├── deploy_challenge.sh
    ├── entrypoint.sh
    ├── my_challenge_with_flag
    └── ctf.xinetd
```


flag *not* in binary:
```
my_challenge_deploy/
├── public/
│   └── my_challenge (compiled binary)
└── private/
    ├── Dockerfile
    ├── docker-compose.yml
    ├── deploy_challenge.sh
    ├── entrypoint.sh
    ├── my_challenge
    ├── flag.txt
    └── ctf.xinetd
```


---

**Enjoy hacking, and happy CTFing! 🎮💻**

---
