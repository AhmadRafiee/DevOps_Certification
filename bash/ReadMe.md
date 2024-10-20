# Bash Scripting

### Basic Structure of a Bash Script
  - **Shebang (#!):** The shebang line at the top of the script indicates the script's interpreter. For a Bash script, this is usually #!/bin/bash.
  - **Comments:** Comments are lines that are not executed by the script. They start with a `#` and are used to explain the code or provide information.
  - **Variables:** Variables store data that can be used and manipulated throughout the script. They are defined by assigning a value to a name without spaces.
  - **Echo Statement:** The echo command is used to print text to the terminal.


### ANSI Escape Codes
ANSI escape codes are sequences of characters that control the formatting of text in the terminal. These codes start with the escape character \033 followed by [ and then one or more numerical codes ending with m.

#### Common ANSI Codes
**Text Color:**
  - **Black:** \033[0;30m
  - **Red:** \033[0;31m
  - **Green:** \033[0;32m
  - **Yellow:** \033[0;33m
  - **Blue:** \033[0;34m
  - **Magenta:** \033[0;35m
  - **Cyan:** \033[0;36m
  - **White:** \033[0;37m

**Background Color:**
  - **Black:** \033[40m
  - **Red:** \033[41m
  - **Green:** \033[42m
  - **Yellow:** \033[43m
  - **Blue:** \033[44m
  - **Magenta:** \033[45m
  - **Cyan:** \033[46m
  - **White:** \033[47m

**Text Styles:**
  - **Reset:** \033[0m (Reset all attributes)
  - **Bold:** \033[1m
  - **Underline:** \033[4m

#### Using Colors in Bash Scripts
To use these codes in a Bash script, you simply include them in the echo statements. Here’s an example of a script that demonstrates various colors and styles:

```bash
#!/bin/bash

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'

# Using Colors and Styles
echo -e "${RED}This is red text${RESET}"
echo -e "${GREEN}This is green text${RESET}"
echo -e "${YELLOW}This is yellow text${RESET}"
echo -e "${BLUE}This is blue text${RESET}"
echo -e "${MAGENTA}This is magenta text${RESET}"
echo -e "${CYAN}This is cyan text${RESET}"
echo -e "${WHITE}This is white text${RESET}"
echo -e "${BOLD}This is bold text${RESET}"
echo -e "${UNDERLINE}This is underlined text${RESET}"

# Combining Colors and Styles
echo -e "${BOLD}${RED}This is bold red text${RESET}"
echo -e "${UNDERLINE}${GREEN}This is underlined green text${RESET}"
```

#### Advanced Usage: Functions for Colored Output

To make your script cleaner and more maintainable, you can define functions for colored output:
```bash
#!/bin/bash

# Color Functions
function print_red {
    echo -e "\033[0;31m$1\033[0m"
}

function print_green {
    echo -e "\033[0;32m$1\033[0m"
}

function print_yellow {
    echo -e "\033[0;33m$1\033[0m"
}

# Usage of Color Functions
print_red "This is red text"
print_green "This is green text"
print_yellow "This is yellow text"
```

### Reading input in a Bash script

Reading input in a Bash script is a common requirement, especially for creating interactive scripts where the user needs to provide information during execution. The read command is used for this purpose. Here's a detailed explanation of how to use the read command, along with examples and various options you can use to customize its behavior.

#### Basic Usage
The simplest form of the read command reads a single line of input from the standard input (usually the keyboard) and stores it in a variable.

```bash
read variable_name
```
**Example:**
```bash
#!/bin/bash

echo "Please enter your name:"
read name
echo "Hello, $name!"
```
In this example, the script prompts the user to enter their name. The input is stored in the variable name, and then it is used in the greeting message.

#### Options and Usage
**Prompt with -p:** The -p option allows you to specify a prompt directly with the read command.
```bash
read -p "Enter your age: " age
echo "You are $age years old."
```

**Silent Input with -s:** The -s option makes the input silent, which is useful for passwords or other sensitive information.
```bash
read -sp "Enter your password: " password
echo
echo "Password entered."
```

**Timeout with -t:** The -t option specifies a timeout in seconds. If the user doesn't enter input within the specified time, the read command exits.
```bash
read -t 5 -p "Enter your username (5 seconds to respond): " username
echo "You entered: $username"
```

**Limiting Input Length with -n:** The -n option limits the number of characters the user can input.
```bash
read -n 4 -p "Enter a 4-digit PIN: " pin
echo
echo "Your PIN is $pin"
```

**Reading Multiple Variables:** You can read multiple variables in a single read statement. The input is split based on spaces or tabs.
```bash
read -p "Enter your first and last name: " first_name last_name
echo "First Name: $first_name, Last Name: $last_name"
```

**Using a Default Value:** You can provide a default value if no input is given by the user. This is done using parameter expansion.
```bash
read -p "Enter your country [USA]: " country
country=${country:-USA}
echo "Country: $country"
```

**Reading an Array:** The -a option allows you to read the input into an array.
```bash
echo "Enter several words separated by spaces:"
read -a words
echo "You entered: ${words[@]}"
```

**Reading from a File Descriptor with -u:**The -u option reads input from a specified file descriptor instead of standard input.
```bash
exec 3<file.txt
read -u 3 line
echo "First line from file: $line"
exec 3<&-
```

**Example: Interactive Script**
Here's a more comprehensive example of an interactive Bash script that uses multiple read options:

```bash
#!/bin/bash

echo "Welcome to the interactive script!"

# Read name with a prompt
read -p "Please enter your name: " name

# Read age with a prompt
read -p "Enter your age: " age

# Read a password silently
read -sp "Enter your password: " password
echo

# Read multiple words into an array
read -p "Enter your favorite colors (space-separated): " -a colors

# Read with a timeout
read -t 5 -p "Enter your hobby (you have 5 seconds): " hobby

# Display the collected information
echo
echo "Summary:"
echo "Name: $name"
echo "Age: $age"
echo "Password: $password"
echo "Favorite colors: ${colors[@]}"
echo "Hobby: ${hobby:-No input}"

echo "Thank you for using the interactive script!"
```

### File Testing Operators
Here's a list of common file testing operators:

**Existence and Type:**
  - -e: Checks if a file exists.
  - -f: Checks if a file exists and is a regular file.
  - -d: Checks if a directory exists.
  - -L: Checks if a file exists and is a symbolic link.
  - -b: Checks if a file exists and is a block special file.
  - -c: Checks if a file exists and is a character special file.
  - -p: Checks if a file exists and is a named pipe.
  - -S: Checks if a file exists and is a socket.

**File Permissions:**
  - -r: Checks if a file exists and is readable.
  - -w: Checks if a file exists and is writable.
  - -x: Checks if a file exists and is executable.
  - -s: Checks if a file exists and is not empty.

**File Comparison:**
  - -nt: Checks if one file is newer than another.
  - -ot: Checks if one file is older than another.
  - -ef: Checks if two files have the same device and inode numbers.

**Example file testing scripts**

```bash
#!/bin/bash

# File to test
file="testfile.txt"
dir="testdir"

# Check if file exists
if [ -e "$file" ]; then
    echo "$file exists."
else
    echo "$file does not exist."
fi

# Check if file is a regular file
if [ -f "$file" ]; then
    echo "$file is a regular file."
else
    echo "$file is not a regular file."
fi

# Check if directory exists
if [ -d "$dir" ]; then
    echo "$dir is a directory."
else
    echo "$dir is not a directory."
fi

# Check if file is readable
if [ -r "$file" ]; then
    echo "$file is readable."
else
    echo "$file is not readable."
fi

# Check if file is writable
if [ -w "$file" ]; then
    echo "$file is writable."
else
    echo "$file is not writable."
fi

# Check if file is executable
if [ -x "$file" ]; then
    echo "$file is executable."
else
    echo "$file is not executable."
fi

# Check if file is not empty
if [ -s "$file" ]; then
    echo "$file is not empty."
else
    echo "$file is empty."
fi
```


# 🔗 Links
[![Site](https://img.shields.io/badge/Dockerme.ir-0A66C2?style=for-the-badge&logo=docker&logoColor=white)](https://dockerme.ir/)
[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/ahmad-rafiee/)
[![Telegram](https://img.shields.io/badge/telegram-0A66C2?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/dockerme)
[![YouTube](https://img.shields.io/badge/youtube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtube.com/@dockerme)
[![Instagram](https://img.shields.io/badge/instagram-FF0000?style=for-the-badge&logo=instagram&logoColor=white)](https://instagram.com/dockerme)