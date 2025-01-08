#!/bin/bash
set -e
# This file creates new vpn client config and generate qrcode

BASE_PATH="/etc/wireguard"
CLIENT_FOLDER_PATH="${BASE_PATH}/clients"
BACKUPS_FOLDER_PATH="${BASE_PATH}/backups"

WG0_CONFIG_PATH="${BASE_PATH}/wg0.conf"
ENV_FILE_PATH="${BASE_PATH}/.env"

load_env() {

  if [ -f "${ENV_FILE_PATH}" ]; then
    set -a
    source "${ENV_FILE_PATH}"
    set +a

    printf "ℹ️ Env variables have been loaded successfully!\n\n" >&2

  else
    printf "❌.env file is not found!\n\n" >&2
    exit 1
  fi

}


current_timestamp() {
  date +"%Y-%m-%d_%H-%M"
}

get_config_name_for_backup() {
  echo "backup_wg0_$(current_timestamp).conf"
}

backup_config() {
  filename="$(get_config_name_for_backup)"
  cp "${WG0_CONFIG_PATH}" "${BACKUPS_FOLDER_PATH}/${filename}"

  printf "ℹ️ Backup has been done. Backup's filename -> ${filename}\n\n" >&2
}

get_last_number_in_filename() {
  filename_prefix=$1


  next_number=$(
    ls clients/${filename_prefix}* 2>/dev/null |                # List pvk files
    sed 's/[^0-9]*//g' |                        # Extract numbers
    sort -n |                                   # Sort numerically
    tail -n 1 |                                 # Get the highest number
    awk '{print $1 + 1}'                        # Increment by 1
  )

  # If there are no pvk files, start from 1
  if [[ -z $next_number ]]; then
    next_number=1
  fi

  echo "${next_number}"
}


get_client_number_postfix() {
  new_pvk_number=$(get_last_number_in_filename "pvk")
  printf "ℹ️ new_pvk_number=${new_pvk_number}\n" >&2

  new_pubk_number=$(get_last_number_in_filename "pubk")
  printf "ℹ️ new_pubk_number=${new_pubk_number}\n" >&2

  new_wg_number=$(get_last_number_in_filename "wg")
  printf "ℹ️ new_wg_number=${new_wg_number}\n" >&2

  if [ "${new_pvk_number}" = "${new_pubk_number}" ] && [ "${new_pvk_number}" = "${new_wg_number}" ] && [ "${new_pubk_number}" = "${new_wg_number}" ]; then
    printf "✅All the files has a right identical number! Go on...\n\n" >&2
    number="${new_pvk_number}"
  else
    printf "❌Numbers of the files are not identical!!! Script will be terminated\n" >&2
    number=-1
  fi

  echo "${number}"
}


generate_client_keys() {
  client_number_postfix=$1
  cd "${CLIENT_FOLDER_PATH}"

  pvk_name="pvk${client_number_postfix}"
  pubk_name="pubk${client_number_postfix}"

  umask 077
  wg genkey | tee "${pvk_name}" | wg pubkey > "${pubk_name}"

  printf "ℹ️ private key is generated into file ${pvk_name}\n" >&2
  printf "ℹ️ public key is generated into file ${puvk_name}\n\n" >&2
}

get_incremented_client_allowed_ip() {

    # Extract the last AllowedIPs line
    last_ip=$(grep -oP 'AllowedIPs\s*=\s*\K[\d.]+(?=/32)' "${WG0_CONFIG_PATH}" | tail -n1)

    # Split the IP into its components
    IFS='.' read -r a b c d <<< "$last_ip"

    # Increment the last octet
    d=$((d + 1))

    # Combine back the IP and append /32
    new_ip="${a}.${b}.${c}.${d}/32"
    printf "ℹ️ new_AllowedIP=${new_ip}\n\n" >&2

    echo "${new_ip}"
}

append_new_client_to_wg0_config() {
  client_number_postfix=$1
  client_ip=$2
  pubk_filename="${CLIENT_FOLDER_PATH}/pubk${client_number_postfix}"
  public_key=$(< "$pubk_filename")

    # Append the new peer configuration
  cat <<EOF >> "${WG0_CONFIG_PATH}"

# client${client_number_postfix}
[Peer]
PublicKey = $public_key
AllowedIPs = $client_ip
EOF

  printf "ℹ️ client${client_number_postfix} is appended into main config called - ${WG0_CONFIG_PATH}\n\n" >&2
}


create_client_config_file() {
  client_number_postfix=$1
  client_ip=$2

  filename="wg${client_number_postfix}.conf"
  pvk_filename="${CLIENT_FOLDER_PATH}/pvk${client_number_postfix}"
  client_private_key=$(< "$pvk_filename")


  cat <<EOF >> "${CLIENT_FOLDER_PATH}/${filename}"

[Interface] 
Address = $client_ip
PrivateKey = $client_private_key
DNS = $SERVER_DNS
[Peer] 
AllowedIPs = 0.0.0.0/0 
Endpoint =  ${SERVER_ENDPOINT}:${SERVER_PORT}
PublicKey = $SERVER_PUBLIC_KEY
#PersistentKeepalive = 15
EOF

 chmod 600 "${CLIENT_FOLDER_PATH}/${filename}"

 printf "ℹ️ Client config file is created with the name -> ${CLIENT_FOLDER_PATH}/${filename}"

}


restart_wireguard() {
  wg syncconf wg0 <(wg-quick strip wg0)

  printf "ℹ️ WireGuard service has been restarted!\n\n" >&2
}

generate_qrcode() {
  client_number_postfix=$1

  config_name="wg${client_number_postfix}.conf"
  config_filepath="${CLIENT_FOLDER_PATH}/${config_name}"

  qrencode -t ansiutf8 < $config_filepath

  printf "ℹ️ Qr code has been generated!\n\n"
}

main() {
  printf "ℹ️ Start...\n\n"

  #env_loaded_successfully="$(load_env)"
  #if [ "${env_loaded_successfully}" = "-1" ]; then
  #  printf  "\n------------❌❌❌Script has been terminated successfully!❌❌❌------------\n" >&2
  #  exit 1
  # fi


  backup_config
  client_number_postfix="$(get_client_number_postfix)"

  if [ "${client_number_postfix}" = "-1" ]; then
    printf  "\n------------❌❌❌Script has been terminated successfully!❌❌❌------------\n" >&2
    exit 1
  fi

  generate_client_keys "${client_number_postfix}"

  new_allowed_ip=$(get_incremented_client_allowed_ip)
  append_new_client_to_wg0_config "${client_number_postfix}" "${new_allowed_ip}"

  create_client_config_file "${client_number_postfix}" "${new_allowed_ip}"

  restart_wireguard
  generate_qrcode "${client_number_postfix}"
  printf "\n------------✅✅✅Script has been executed successfully!✅✅✅------------\n" >&2
}

load_env
main

