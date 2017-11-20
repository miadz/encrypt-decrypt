#!/bin/bash
# Copyright (c) 2017 David Kim
# This program is licensed under the "MIT License".

# Encrypt-Decrypt files using OpenSSL.
# Cipher: AES 256 Cipher Blocker Chaining (cbc)
# Usage: source encrypt-decrypt.sh
#        encrypt source_file
#        decrypt source_file.aes-256-cbc

encrypt() {
  FILENAME="$1"
  if [[ $FILENAME ]] ; then                                 # If command argument exists...
    if [[ -d "$FILENAME" ]] ; then                          # If $FILENAME is a directory, create a tar archive...
      FILENAME="$(echo "$FILENAME" | sed -e 's|\/||')"      # Remove the trailing '/' in the command argument.
      tar -cf "${FILENAME}.tar" "$FILENAME"
      FILENAME="${FILENAME}.tar"                            # Set $FILENAME to the tar archive.
    elif [[ ! -f "$FILENAME" ]] ; then                      # If $FILENAME is not a regular file...
      echo "$FILENAME is not a valid file or directory."
      exit 1                                                # ...exit immediately.
    fi

    HINT_EXISTS=''
    if [[ -f passwd.hint ]] ; then                          # If passwd.hint file exists...
      printf "passwd.hint file found.\n"
      HINT_EXISTS='true'
      PASSWD_HINT=''
      NL=$'\n'
      while read line ; do                                  # Prepend password hint to $PASSWD_HINT
        PASSWD_HINT=$(echo -ne "${PASSWD_HINT}\n${line}")
      done < passwd.hint
    else
      printf "passwd.hint file not found.\n"
      printf "Enter in a password hint: "
      read PASSWD_HINT
    fi

    openssl aes-256-cbc -a -salt -in "$FILENAME" -out "${FILENAME}.aes-256-cbc"       # Run OpenSSL.

    echo -e "\n$(printf -- '-%.0s' {1..64})\n$(cat "${FILENAME}.aes-256-cbc")" > "${FILENAME}.aes-256-cbc"        # Prepend a separator in the encrypted file.
    if [[ $HINT_EXISTS ]] ; then
      echo -e "${PASSWD_HINT}$(cat "${FILENAME}.aes-256-cbc")" > "${FILENAME}.aes-256-cbc"                          # Now, prepend $PASSWD_HINT.
      tail -n +2 "${FILENAME}.aes-256-cbc" > tmp                                                                    # Remove the first line which is empty.
      mv tmp "${FILENAME}.aes-256-cbc"
    else
      echo -e "${PASSWD_HINT}$(cat "${FILENAME}.aes-256-cbc")" > "${FILENAME}.aes-256-cbc"                          # Now, prepend $PASSWD_HINT.
    fi

    if [[ "$FILENAME" =~ \.tar$ ]] ; then                   # Clean up intermediary files.
      rm "$FILENAME"
    fi

    echo "Now you safely remove the original file."
  else
    echo "usage: encrypt source_file"
  fi
}

decrypt() {
  FILENAME="$1"
  if [[ $FILENAME ]] ; then
    line=$(( $(cat $FILENAME | grep -n -E -- "-{64}" | cut -d : -f 1) + 1 ))                      # Get the line number after password hint block.
    sed '/----------------------------------------------------------------/,$!d' "$FILENAME" |    # Remove the lines containing the password hint.
    sed '1d' > "${FILENAME}.intermediate"

    FILENAME="${FILENAME}.intermediate"
    FILEOUT="$(echo "${FILENAME}" | sed -e 's|\.aes-256-cbc\.intermediate||')"

    openssl aes-256-cbc -d -a -in "${FILENAME}" -out "$FILEOUT" 2> /dev/null                      # Run OpenSSL.
    if [[ $(echo $?) != 0 ]] ; then                                                               # If exit code is not 0, return immediately.
      echo "Wrong Password."
      rm "${FILENAME}" "${FILEOUT}"
      return
    fi

    if [[ "$FILEOUT" =~ \.tar$ ]] ; then                    # If $FILEOUT is a tar archive, extract to disk.
      tar -xf "$FILEOUT"
      rm "$FILEOUT"
    fi
    rm "${FILENAME}"             # Clean up intermediary files.

    echo "Now you safely remove the encrypted file."
  else
    echo "usage: decrypt source_file.aes-256-cbc"
  fi
}
