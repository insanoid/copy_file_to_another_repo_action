#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FILE" ]
then
  echo "Source file must be defined"
  return -1
fi

if [ -z "$INPUT_DESTINATION_BRANCH" ]
then
  INPUT_DESTINATION_BRANCH=main
fi
OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

CLONE_DIR=$(mktemp -d)

echo "Cloning destination git repository"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"
git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

if [ "$INPUT_DELETE_BEFORE_COPYING" = "true" ]; then
  echo "Cleaning directory before starting"
  rm -rf $CLONE_DIR/$INPUT_DESTINATION_FOLDER
fi

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER

while [ "$INPUT_SOURCE_FILE" ] ;do
  # extract the substring from start of string up to delimiter.
  # this is the first "element" of the string.
  iter=${INPUT_SOURCE_FILE%%;*}
  echo "> [$iter]"
  if [ "$INPUT_COPY_ONLY_FILES_INSIDE_DIRECTORY" = "true" ]; then
    echo "Copying contents only to git repo"
    cp -a $iter"/." "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
  else
    echo "Copying entire folder/file to git repo"
    cp -R "$iter" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
  fi
  # if there's only one element left, set `IN` to an empty string.
  # this causes us to exit this `while` loop.
  # else, we delete the first "element" of the string from IN, and move onto the next.
  [ "$INPUT_SOURCE_FILE" = "$iter" ] && \
      INPUT_SOURCE_FILE='' || \
      INPUT_SOURCE_FILE="${INPUT_SOURCE_FILE#*;}"
  done

cd "$CLONE_DIR"

if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
then
  git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
fi

if [ -z "$INPUT_COMMIT_MESSAGE" ]
then
  INPUT_COMMIT_MESSAGE="Update from https://github.com/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
fi

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "$INPUT_COMMIT_MESSAGE"
  echo "Pushing git commit"
  git push -u origin HEAD:$OUTPUT_BRANCH
else
  echo "No changes detected"
fi
