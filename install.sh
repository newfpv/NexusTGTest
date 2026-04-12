#!/bin/bash

# Colors for friendly output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/NexusTG"
REPO_URL="https://github.com/newfpv/NexusTGTest.git"
TOTAL_STEPS=5

# Function to draw a nice progress bar with percentages
draw_progress_bar() {
    local step=$1
    local text=$2
    local filled=$(( (step * 20) / TOTAL_STEPS ))
    local empty=$(( 20 - filled ))
    local percent=$(( (step * 100) / TOTAL_STEPS ))
    local bar_filled=$(printf "%${filled}s" | tr ' ' '█')
    local bar_empty=$(printf "%${empty}s" | tr ' ' '░')
    echo -e "\n${CYAN}[${bar_filled}${bar_empty}] ${percent}% | Step ${step}/${TOTAL_STEPS} - ${text}${NC}"
}

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  ✨ Welcome to the NexusTG (AI Twin) Installer ✨  ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "Sit back and relax! I'll do all the heavy lifting for you. 🚀"

# ---------------------------------------------------------
# STEP 1: Tools
# ---------------------------------------------------------
draw_progress_bar 1 "Installing necessary tools (git, curl)..."
if ! command -v git &> /dev/null || ! command -v curl &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq git curl > /dev/null 2>&1
    echo -e "${GREEN}✔ Tools installed!${NC}"
else
    echo -e "${GREEN}✔ Tools are already installed!${NC}"
fi

# ---------------------------------------------------------
# STEP 2: Repository
# ---------------------------------------------------------
draw_progress_bar 2 "Downloading the project files..."
if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    git pull -q
    echo -e "${GREEN}✔ Project files updated!${NC}"
else
    git clone -q "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "${GREEN}✔ Project downloaded to $INSTALL_DIR!${NC}"
fi

# ---------------------------------------------------------
# STEP 3: Docker
# ---------------------------------------------------------
draw_progress_bar 3 "Setting up Docker & Compose..."
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}🐳 Docker is missing. Installing it now (this might take a minute)...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    echo -e "${GREEN}✔ Docker installed!${NC}"
else
    echo -e "${GREEN}✔ Docker is already installed!${NC}"
fi

if ! docker compose version &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin > /dev/null 2>&1
    echo -e "${GREEN}✔ Docker Compose installed!${NC}"
fi

# ---------------------------------------------------------
# STEP 4: Configuration
# ---------------------------------------------------------
draw_progress_bar 4 "Bot Configuration & Language..."

echo -e "\n${CYAN}🌍 What language would you like your bot to use?${NC}"
LANG_FILES=(language_*.json)
if [ -e "${LANG_FILES[0]}" ]; then
    for i in "${!LANG_FILES[@]}"; do
        LANG_CODE=$(echo "${LANG_FILES[$i]}" | sed -n 's/language_\(.*\)\.json/\1/p')
        echo "   $((i+1)). $LANG_CODE"
    done
    
    echo -e "${YELLOW}👉 Please enter the number (press Enter for default EN): ${NC}"
    read -r lang_choice
    
    if ! [[ "$lang_choice" =~ ^[0-9]+$ ]] || [ "$lang_choice" -le 0 ] || [ "$lang_choice" -gt "${#LANG_FILES[@]}" ]; then
        if [[ " ${LANG_FILES[*]} " =~ " language_EN.json " ]]; then
            SELECTED_LANG="language_EN.json"
        else
            SELECTED_LANG="${LANG_FILES[0]}"
        fi
    else
        SELECTED_LANG="${LANG_FILES[$((lang_choice-1))]}"
    fi
    echo -e "${GREEN}✅ Selected language: $SELECTED_LANG${NC}"
else
    echo -e "${RED}⚠️ No translation files found! Defaulting to language_EN.json${NC}"
    SELECTED_LANG="language_EN.json"
fi

echo -e "\n${CYAN}⚙️  Connecting your Telegram Bot${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}====================================================${NC}"
    echo -e "🤖 ${GREEN}How to get your TG_BOT_TOKEN:${NC}"
    echo -e "1. Open Telegram and search for ${CYAN}@BotFather${NC} (with a blue tick)."
    echo -e "2. Send the command: ${CYAN}/newbot${NC}"
    echo -e "3. Choose a name and a username for your bot."
    echo -e "4. BotFather will give you a token (e.g. 1234567890:ABCdef...)."
    echo -e "${YELLOW}====================================================${NC}\n"

    read -p "🔑 Please paste your TG_BOT_TOKEN here: " TG_BOT_TOKEN

    echo "TG_BOT_TOKEN=$TG_BOT_TOKEN" > .env
    echo "LANG_FILE=$SELECTED_LANG" >> .env
    echo -e "${GREEN}✅ Token saved successfully!${NC}"
else
    echo -e "${GREEN}✅ Configuration file (.env) already exists. Updating language...${NC}"
    if grep -q "LANG_FILE=" .env; then
        sed -i "s/^LANG_FILE=.*/LANG_FILE=$SELECTED_LANG/" .env
    else
        echo "LANG_FILE=$SELECTED_LANG" >> .env
    fi
fi

# ---------------------------------------------------------
# STEP 5: Launch
# ---------------------------------------------------------
draw_progress_bar 5 "Building and launching the bot..."
echo -e "${YELLOW}This might take a couple of minutes depending on your server speed...${NC}"
docker compose up -d --build

echo -e "\n${CYAN}====================================================${NC}"
echo -e "${GREEN} 🎉 ALL DONE! NexusTG is now running in the background! 🎉${NC}"
echo -e "${CYAN}====================================================${NC}\n"

echo -e "Go to Telegram and send ${YELLOW}/start${NC} to your bot to finish the setup!\n"

echo -e "${GREEN}📌 Quick Guide & Useful Commands:${NC}"
echo -e "You can run these commands from the installation folder (${YELLOW}$INSTALL_DIR${NC}):\n"
echo -e "🔹 ${CYAN}cd $INSTALL_DIR${NC}                 - Navigate to the bot folder"
echo -e "🔹 ${CYAN}docker compose logs -f${NC}        - View real-time bot logs (Ctrl+C to exit)"
echo -e "🔹 ${CYAN}docker compose restart${NC}        - Restart the bot safely"
echo -e "🔹 ${CYAN}docker compose down${NC}           - Stop the bot completely"
echo -e "🔹 ${CYAN}docker compose up -d --build${NC}  - Update and start the bot after changing files"
echo -e "\n${GREEN}Enjoy using your NexusTG! 🤖✨${NC}\n"