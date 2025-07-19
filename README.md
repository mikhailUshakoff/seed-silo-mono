# Seed Silo
Seed Silo is a cryptocurrency wallet app built using Flutter that communicates with an ESP32-based hardware wallet over serial. 
The ESP32 device securely signs transactions, providing an extra layer of security by keeping private keys off the mobile/PC client.

#Note
##AES128-CBC
Avoid reusing the ciphertext or IV. If you ever re-encrypt the same data with the same IV, you leak information about the key. So always generate a new IV when re-encrypting.
