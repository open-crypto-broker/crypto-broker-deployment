# Clients Compatibility Matrix

This compatibility matrix shows which client supports which profile and which CSR when signing certificates with different CA issuers.

Legend: ✅ - Supported by profile, ❌ - Not Supported by profile

## Go Client

### Profile "Default"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| TEST-CA-NIST-SECP521R1 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |

### Profile "KSA-MODERATE-2020"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Profile "KSA-ADVANCED-2020"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

### Profile "FIPS-140-3-128bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Profile "FIPS-140-3-192bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |

### Profile "FIPS-140-3-256bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |

## Js Client

### Profile "Default"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| TEST-CA-NIST-SECP521R1 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |

### Profile "KSA-MODERATE-2020"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Profile "KSA-ADVANCED-2020"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

### Profile "FIPS-140-3-128bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Profile "FIPS-140-3-192bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |

### Profile "FIPS-140-3-256bit"

| Issuer↓ \ CSR➔ | CSR-RSA-2048 | CSR-RSA-3072 | CSR-RSA-4096 | CSR-RSA-8192 | CSR-RSA-15380 | CSR-NIST-SECP224R1 | CSR-NIST-SECP256R1 | CSR-NIST-SECP384R1 | CSR-NIST-SECP521R1 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TEST-CA-RSA-3072 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP256R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP384R1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TEST-CA-NIST-SECP521R1 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
