Project Review: ESP32 Wallet-Sized Hardware Wallet
This is an interesting embedded project - a hardware wallet for signing Ethereum transactions on ESP32 devices (LilyGO T-Display S3 and Super Mini ESP32-C3). Let me break down the review into several categories:

Overview
Platform: PlatformIO project targeting ESP32 microcontrollers
Purpose: Hardware wallet for signing Ethereum transactions (EIP-1559 type-2 transactions)
Components:
crypto library (secp256k1, keccak256)
TFT display interface
serial communication protocol
AES-GCM encryption for private key storage
Strengths
Security Considerations
Good use of secure_memzero() to clear sensitive data from memory
Proper implementation of recoverable ECDSA signatures
Separation of encryption/decryption logic for key management
Error code handling for various failure scenarios
Code Organization
Clean separation between platform-specific code (main.cpp) and core logic
Well-defined constants and error codes
Modular library structure (secp256k1, sha3_keccak, TFT_eSPI)
Hardware Support
Multi-platform support (ESP32-C3, ESP32-S3)
Proper platformio.ini configuration
Good integration with existing libraries
Areas for Improvement
1. Code Format and Readability
Issue: main.cpp has inconsistent formatting and long functions.

Recommendation: Split the parse_eip1559_tx function into smaller helper functions. The function is doing too much - parsing, validation, and UI rendering.

2. Memory Management
Issue: Large stack variables and potential buffer overflows.


Apply
void setup() {
    // This creates 256-byte buffers on the stack each time
    char buf[256];
    format_hex_string(buf, sizeof(buf), label, data, len, false);
}
Recommendation: Use heap allocation or larger buffers only when needed. Consider using smaller buffers and chunked output for very long hex strings.

3. Security Vulnerabilities
Issue: Key management appears to store encrypted private keys in flash.


Apply
unsigned char encrypted_data[ENCRYPTED_DATA_LEN] = ENCRYPTED_DATA_INITIALIZER;
Recommendations:

Ensure the encryption key is not hardcoded or stored in flash
Consider using hardware-based secure elements if available
Implement proper key derivation from user input (PIN, passphrase)
Add secure boot verification
4. Error Handling
Issue: Inconsistent error handling and return value checking.

Examples:

setup() doesn't validate TFT initialization
parse_eip1559_tx returns error codes but doesn't always clear UI state
Missing bounds checking in RLP parsing
5. UI Issues
Issue: The UI implementation has hardcoded display dimensions and lacks error resilience.

Recommendations:

Add proper screen clearing before each transaction
Implement timeout for confirmation dialogs
Add loading indicator for operation duration
Make UI more accessible (larger fonts, better contrast)
6. Code Quality Issues
Issue: Global mutable state


Apply
bool bSignConfirmationScreen = false;
uint8_t signature[64] = {0};
int rec_id = 0;
uint8_t message[MAX_MSG_LEN];
uint16_t msg_len = 0;
Recommendation: Encapsulate state in a context struct to avoid side effects and improve testability.

Specific Code Issues
RLP Parsing
The RLP parser is generally correct but has edge cases not handled:

Very long lists (>24 bits length prefix)
Malformed input with length > actual data
Transaction Parsing
The EIP-1559 parsing assumes specific data format for ERC-20 transfers:


Apply
if (field_len != 4 + 32 + 32 || memcmp(field, "\xa9\x05\x9c\xbb", 4) != 0)
This validation should be more robust.

Serial Communication
Missing timeout handling for serial communication
No framing protocol (start/end markers) for messages
No checksums for data integrity
Suggestions for Enhancement
1. Security hardening
Implement secure element support if hardware allows
Add hardware random number generation for nonce
Implement proper key rotation
2. User Experience
Add haptic feedback if hardware supports it
Implement button press debouncing
Add visual feedback for operations
Support for transaction preview (fee calculation, recipient info)
3. Protocol improvements

Apply
// Suggested protocol structure
typedef struct {
    uint8_t  version;
    uint8_t  command;
    uint16_t length;
    uint8_t  data[256];
    uint8_t  checksum[4]; // CRC32 or similar
} packet_t;
4. Testing infrastructure
Add unit tests for core crypto functions
Create mock interfaces for TFT/serial for testing
Add simulation mode for development
5. Documentation
Add API documentation
Create user manual for operation
Document security model and threat assumptions
PlatformIO Configuration Improvement
Your current config could be more robust:


Apply
[platformio]
default_envs = lilygo_tdisplay_s3
data_dir = data

[_common_build]
build_flags =
    -DARDUINO_USB_CDC_ON_BOOT=1
    -DARDUINO_USB_MODE=1
    -DDISABLE_ALL_LIBRARY_WARNINGS

[env:lilygo_tdisplay_s3]
board = lilygo-t-displays3
upload_protocol = esptool
build_flags = ${_common_build.build_flags}
    -DLV_LVGL_H_INCLUDE_SIMPLE
build_src_filter =
    +<lilygo_tdisplay_s3/>

[env:super_mini_esp32c3]
# ... similar structure
Quick Wins for Immediate Improvement
Add button debouncing to prevent multiple triggers:

Apply
unsigned long lastButtonPress = 0;
const unsigned long DEBOUNCE_DELAY = 200;

if (digitalRead(up) == LOW && millis() - lastButtonPress > DEBOUNCE_DELAY) {
    lastButtonPress = millis();
    // Handle button press
}
Add watchdog timer for unresponsive states:

Apply
#include <driver/timer.h>
// Configure watchdog to reset if main loop hangs
Implementotaion of secure memzero should use compiler barriers:

Apply
void secure_memzero(void *ptr, size_t len) {
    volatile memset(ptr, 0, len);
    // Compiler barrier to prevent optimization
    __asm__ volatile ("" : : : "memory");
}
Summary
This is a solid foundation for an Ethereum hardware wallet with good understanding of the cryptographic primitives involved. The main concerns are around production-readiness security practices and user experience refinement.

Would you like me to help with any specific aspect of the improvements, such as:

Creating a more robust RLP parser?
Implementing better error handling?
Adding unit tests for the crypto functions?
Refactoring the UI code for better maintainability?