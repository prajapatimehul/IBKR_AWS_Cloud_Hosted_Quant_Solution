import boto3
import os
import re

# Initialize boto3 client
ssm = boto3.client('ssm', region_name='us-east-1')

# Define main and advanced parameters with their descriptions
PARAMETERS_INFO = {
    '/IB_Gateway/TWS_USERID': {'category': 'Main', 'description': 'The TWS username.'},
    '/IB_Gateway/TWS_PASSWORD': {'category': 'Main', 'description': 'The TWS password.'},
    '/IB_Gateway/TRADING_MODE': {'category': 'Main', 'description': 'Options: live, paper, or both. Default: paper', 'default': 'paper'},
    '/IB_Gateway/VNC_SERVER_PASSWORD': {'category': 'Main', 'description': 'VNC server password. If not defined, VNC server will NOT start.'},
    '/IB_Gateway/JUPYTER_TOKEN': {'category': 'Main', 'description': 'Token for Jupyter notebook access.'},
    '/IB_Gateway/TWS_SETTINGS_PATH': {'category': 'Advanced', 'description': 'Settings path used by IBC\'s parameter --tws_settings_path.'},
    '/IB_Gateway/TWS_ACCEPT_INCOMING': {'category': 'Advanced', 'description': 'Options: accept, reject, manual. Default: manual', 'default': 'manual'},
    '/IB_Gateway/READ_ONLY_API': {'category': 'Advanced', 'description': 'Options: yes or no.'},
    '/IB_Gateway/TWOFA_TIMEOUT_ACTION': {'category': 'Advanced', 'description': 'Options: exit or restart. Default: exit', 'default': 'exit'},
    '/IB_Gateway/BYPASS_WARNING': {'category': 'Advanced', 'description': 'Options: yes or no.'},
    '/IB_Gateway/AUTO_RESTART_TIME': {'category': 'Advanced', 'description': 'Time to restart IB Gateway. Format: hh:mm AM/PM'},
    '/IB_Gateway/AUTO_LOGOFF_TIME': {'category': 'Advanced', 'description': 'Auto-Logoff time. Format: hh:mm'},
    '/IB_Gateway/TWS_COLD_RESTART': {'category': 'Advanced', 'description': 'Cold restart time. Format: hh:mm'},
    '/IB_Gateway/SAVE_TWS_SETTINGS': {'category': 'Advanced', 'description': 'Times to save TWS settings. Format: hh:mm hh:mm ...'},
    '/IB_Gateway/RELOGIN_AFTER_TWOFA_TIMEOUT': {'category': 'Advanced', 'description': 'Options: yes or no. Default: no', 'default': 'no'},
    '/IB_Gateway/TWOFA_EXIT_INTERVAL': {'category': 'Advanced', 'description': 'Time interval for 2FA exit.'},
    '/IB_Gateway/TWOFA_DEVICE': {'category': 'Advanced', 'description': 'Second factor authentication device.'},
    '/IB_Gateway/EXISTING_SESSION_DETECTED_ACTION': {'category': 'Advanced', 'description': 'Options: primary, secondary, manual. Default: primary', 'default': 'primary'},
    '/IB_Gateway/ALLOW_BLIND_TRADING': {'category': 'Advanced', 'description': 'Options: yes or no. Default: no', 'default': 'no'},
    '/IB_Gateway/TIME_ZONE': {'category': 'Advanced', 'description': 'Time zone for IB Gateway. Default: Etc/UTC', 'default': 'Etc/UTC'},
    '/IB_Gateway/CUSTOM_CONFIG': {'category': 'Advanced', 'description': 'Options: yes or no. Default: no', 'default': 'no'},
    '/IB_Gateway/JAVA_HEAP_SIZE': {'category': 'Advanced', 'description': 'Java heap size in MB. Default: 768'},
    '/IB_Gateway/SSH_TUNNEL': {'category': 'Advanced', 'description': 'Options: yes, no, or both.'},
    '/IB_Gateway/SSH_OPTIONS': {'category': 'Advanced', 'description': 'Additional options for SSH client.'},
    '/IB_Gateway/SSH_ALIVE_INTERVAL': {'category': 'Advanced', 'description': 'SSH ServerAliveInterval setting. Default: 20', 'default': '20'},
    '/IB_Gateway/SSH_ALIVE_COUNT': {'category': 'Advanced', 'description': 'SSH ServerAliveCountMax setting.'},
    '/IB_Gateway/SSH_PASSPHRASE': {'category': 'Advanced', 'description': 'Passphrase for SSH keys.'},
    '/IB_Gateway/SSH_REMOTE_PORT': {'category': 'Advanced', 'description': 'Remote port for SSH tunnel.'},
    '/IB_Gateway/SSH_USER_TUNNEL': {'category': 'Advanced', 'description': 'user@server to connect to for SSH tunnel.'},
    '/IB_Gateway/SSH_RESTART': {'category': 'Advanced', 'description': 'Seconds to wait before restarting SSH tunnel. Default: 5', 'default': '5'},
    '/IB_Gateway/SSH_VNC_PORT': {'category': 'Advanced', 'description': 'Remote port for VNC SSH tunnel.'}
}

def get_parameter(name):
    try:
        response = ssm.get_parameter(Name=name, WithDecryption=True)
        return response['Parameter']['Value']
    except ssm.exceptions.ParameterNotFound:
        return None

def put_parameter(name, value):
    ssm.put_parameter(
        Name=name,
        Value=value,
        Type='SecureString',
        Overwrite=True
    )

def is_sensitive(param_name):
    return bool(re.search(r'password|token', param_name, re.IGNORECASE))

def mask_sensitive_value(value):
    return '*' * len(value) if value else ''

def manage_parameters(parameters, category):
    changes_made = False
    for param in parameters:
        info = PARAMETERS_INFO[param]
        current_value = get_parameter(param)
        
        prompt = f"{param} ({info['category']})\n"
        prompt += f"Description: {info['description']}\n"
        if 'default' in info:
            prompt += f"Default: {info['default']}\n"
        
        if current_value is not None:
            displayed_value = mask_sensitive_value(current_value) if is_sensitive(param) else current_value
            prompt += f"Current value: {displayed_value}\n"
            change = input(prompt + "Would you like to change it? (yes/no): ").lower()
            if change == 'yes':
                new_value = input("Enter new value: ")
                if new_value:
                    put_parameter(param, new_value)
                    changes_made = True
                    print(f"Parameter {param} updated.")
        else:
            new_value = input(prompt + "Enter value: ")
            if new_value:
                put_parameter(param, new_value)
                changes_made = True
                print(f"Parameter {param} created.")
    
    return changes_made


def main():
    changes_made = False

    # Check if main config exists
    main_parameters = [param for param, info in PARAMETERS_INFO.items() if info['category'] == 'Main']
    advanced_parameters = [param for param, info in PARAMETERS_INFO.items() if info['category'] == 'Advanced']

    main_config_exists = any(get_parameter(param) for param in main_parameters)

    if main_config_exists:
        change_main = input("Main config exists. Would you like to change any main settings (username, password, etc.)? (yes/no): ").lower()
        if change_main == 'yes':
            changes_made = manage_parameters(main_parameters, "Main") or changes_made

    change_advanced = input("Would you like to add or change advanced settings? (yes/no): ").lower()
    if change_advanced == 'yes':
        changes_made = manage_parameters(advanced_parameters, "Advanced") or changes_made

    if changes_made:
        update_choice = input("Changes were made. Do you want to update 1) straight away or 2) next build? (1/2): ")
        if update_choice == '1':
            print("Updating straight away...")
            
            # Placeholder for rebuilding docker container
            print("# TODO: Rebuild docker container via HTTP or SSH command")
        else:
            print("Changes will be applied on next build.")
    else:
        print("No changes were made.")

if __name__ == "__main__"
    main()