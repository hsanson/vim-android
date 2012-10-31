#/bin/sh

TARGET_DIR=javacomplete/after/ftplugin
TARGET_BRANCH=master
rm -rf "$HOME"/.vim/bundle/"$TARGET_DIR"
mkdir -p "$HOME"/.vim/bundle/"$TARGET_DIR"
git archive "$TARGET_BRANCH" | tar -x -C "$HOME"/.vim/bundle/"$TARGET_DIR"
