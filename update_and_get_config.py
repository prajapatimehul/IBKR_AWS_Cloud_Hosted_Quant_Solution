import boto3
import os
import re
import logging
import subprocess
from datetime import datetime
from pathlib import Path


# Initialize boto3 client
ssm = boto3.client('ssm', region_name='us-east-1')

# Set up logging
home_dir = str(Path.home())
log_dir = os.path.join(home_dir, 'logs')
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, f"ib_gateway_config_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(filename=log_file, level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Define main and advanced parameters with their descriptions
PARAMETERS_INFO = {
    '/IB_Gateway/TWS_USERID': {'category': 'Main', 'description': 'The TWS username.'},
    '/IB_Gateway/TWS_PASSWORD': {'category': 'Main', 'description': 'The TWS password.'},
    '/IB_Gateway/TWS_USERID_PAPER': {'category': 'Main', 'description': 'The TWS username for papertrading.'},
    '/IB_Gateway/TWS_PASSWORD_PAPER': {'category': 'Main', 'description': 'The TWS password for papertrading.'},
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
    logging.info(f"Parameter {name} has been updated/created.")

def is_sensitive(param_name):
    return bool(re.search(r'password|token', param_name, re.IGNORECASE))

def mask_sensitive_value(value):
    return '*' * len(value) if value else ''

def ensure_parameters_exist():
    for param, info in PARAMETERS_INFO.items():
        if get_parameter(param) is None:
            default_value = info.get('default', '')
            if default_value:
                put_parameter(param, default_value)
                logging.info(f"Parameter {param} added with default value.")
            else:
                logging.info(f"Parameter {param} does not exist and has no default value.")

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
        else:
            new_value = input(prompt + "Enter value: ")
            if new_value:
                put_parameter(param, new_value)
                changes_made = True
    
    return changes_made

def add_custom_env_variables():
    changes_made = False
    while True:
        new_var = input("Enter a new environment variable name (or press Enter to finish): ")
        if not new_var:
            break
        
        new_param = f"/IB_Gateway/{new_var}"
        if new_param in PARAMETERS_INFO:
            logging.info(f"Parameter {new_param} already exists in the predefined list.")
            continue
        
        description = input("Enter a description for this variable: ")
        default = input("Enter a default value (optional): ")
        category = input("Enter category (Main/Advanced): ")
        
        PARAMETERS_INFO[new_param] = {
            'category': category,
            'description': description,
            'default': default
        }
        
        value = input(f"Enter value for {new_param}: ")
        put_parameter(new_param, value)
        changes_made = True
        logging.info(f"New parameter {new_param} added to the parameter store.")
    
    return changes_made

def execute_update_script():
    script_path = os.path.join(os.path.dirname(__file__), 'ssm-dynamic-trigger-script-updated.sh')
    try:
        result = subprocess.run(['bash', script_path], capture_output=True, text=True, check=True)
        logging.info(f"Update script executed successfully. Output: {result.stdout}")
        print("Update script executed successfully. Check the log file for details.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing update script: {e}")
        logging.error(f"Script output: {e.output}")
        print(f"Error executing update script. Check the log file for details.")


def main():
    logging.info("Starting IB Gateway configuration update process.")
    
    # Ensure all parameters exist in the store
    ensure_parameters_exist()

    changes_made = False

    # Check if main config exists
    main_parameters = [param for param, info in PARAMETERS_INFO.items() if info['category'] == 'Main']
    advanced_parameters = [param for param, info in PARAMETERS_INFO.items() if info['category'] == 'Advanced']

    change_main = input("Would you like to change any main settings (username, password, etc.)? (yes/no): ").lower()
    if change_main == 'yes':
        changes_made = manage_parameters(main_parameters, "Main") or changes_made

    change_advanced = input("Would you like to add or change advanced settings? (yes/no): ").lower()
    if change_advanced == 'yes':
        changes_made = manage_parameters(advanced_parameters, "Advanced") or changes_made

    # Add custom environment variables
    add_custom = input("Would you like to add new custom environment variables? (yes/no): ").lower()
    if add_custom == 'yes':
        changes_made = add_custom_env_variables() or changes_made

    if changes_made:
        update_choice = input("Changes were made. Do you want to update 1) straight away or 2) next build? (1/2): ")
        if update_choice == '1':
            print("Updating straight away...")
            logging.info("User chose to update straight away.")
            execute_update_script()
        else:
            print("Changes will be applied on next build.")
            logging.info("Changes will be applied on next build.")
    else:
        print("No changes were made.")
        logging.info("No changes were made.")

    logging.info("IB Gateway configuration update process completed.")
    print(f"Log file has been created at: {log_file}")

if __name__ == "__main__":
    main()