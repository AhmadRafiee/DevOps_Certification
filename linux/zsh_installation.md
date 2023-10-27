Update the packages
```bash
sudo apt update
sudo apt upgrade
```
Install prerequisite packages zsh
```bash
sudo apt install -y zsh
```

Install oh-my-zsh now
Oh My Zsh is installed by running one of the following commands in your terminal.

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### autosuggestions
Clone this repository into $ZSH_CUSTOM/plugins (by default ~/.oh-my-zsh/custom/plugins)
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```
Add the plugin to the list of plugins for Oh My Zsh to load (inside ~/.zshrc):
```bash
plugins=(
    # other plugins...
    zsh-autosuggestions
)
```
Start a new terminal session.


If you want Syntax Highlighting
Clone the ZSH Syntax Highlighting
```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.zsh-syntax-highlighting" --depth 1
```
Add syntax-highlighting in .zshrc Configuration
```bash
echo "source $HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$HOME/.zshrc"
```


Change your Default Shell
```bash
chsh -s /bin/zsh
```
And If anything goes wrong, you can revert back to your default shell by
```bash
chsh -s /bin/bash
```