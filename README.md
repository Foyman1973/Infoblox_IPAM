# Infoblox_IPAM
This script uses vCenter and will keep ESXi kernel adapters registered in Infoblox IPAM and an associated DNS view.
The script is controlled by a vCenter list (see vCenter list file in repositories) and an XML based Config.xml file to store core configurations used within the script itself. (see ExampleConfig.xml)  Copy the example to a config.xml file and customize for your environment before use.

All HASH values are PowerShell SecureString values so ensure you generate the hash value in the session that will be running the script to make sure it can be properly decoded.
