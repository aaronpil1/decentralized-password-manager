# Decentralized Password Manager Smart Contract

A secure and decentralized password manager built on the Stacks blockchain using Clarity smart contracts. This smart contract enables users to register, store, retrieve, update, and manage their encrypted passwords while maintaining full ownership and control of their data.

---

## Features

- User registration and subscription system.
- Encrypted password storage per user.
- Per-user settings (e.g., auto-lock, 2FA, backup).
- Access logging for actions (store, retrieve, update).
- Limited password list (max 100 per user).
- Secure deletion of passwords.
- Admin controls for toggling contract status and updating storage fees.
- Read-only functions for statistics and user data access.

---

## Contract Structure

### Data Structures

- **users**: Stores registered user data.
- **passwords**: Maps each user's encrypted password data.
- **user-password-list**: Tracks each user's list of password IDs.
- **access-logs**: Stores logs of password access actions.
- **user-settings**: Manages individual user preferences.

### Constants

- `CONTRACT_OWNER`: Deployer of the contract.
- `storage-fee`: Fee (in microSTX) for registering or renewing subscriptions.

### Error Codes

- `ERR_UNAUTHORIZED (u100)`: Unauthorized access.
- `ERR_NOT_FOUND (u101)`: Missing entry.
- `ERR_ALREADY_EXISTS (u102)`: Entry already exists.
- `ERR_INVALID_INPUT (u103)`: Input validation failure.
- `ERR_INSUFFICIENT_FUNDS (u104)`: Transfer failed.

---

## Public Functions

| Function | Description |
|---------|-------------|
| `register-user` | Registers a new user after paying a storage fee. |
| `store-password` | Stores a new password entry for the user. |
| `get-password` | Retrieves a password entry by ID. |
| `update-password` | Updates an existing password entry. |
| `delete-password` | Deletes a password from storage. |
| `update-user-settings` | Updates user-specific settings like auto-lock and 2FA. |
| `renew-subscription` | Renews a user's subscription for another year. |
| `toggle-contract-status` | Admin: Enables or disables the contract. |
| `update-storage-fee` | Admin: Updates the registration/storage fee. |

---

## Read-Only Functions

| Function | Description |
|---------|-------------|
| `get-user-passwords` | Returns a list of a user's password IDs. |
| `get-user-profile` | Returns user profile information. |
| `get-total-users` | Returns the total number of registered users. |
| `get-contract-info` | Returns contract metadata: status, user count, fee, owner. |

---

## Access Control

- Only the **contract owner** can modify system-level settings like `storage-fee` and toggle contract status.
- Only **registered users** can store, retrieve, and manage their password entries.
- Access is **subscription-based** (1 year = ~144000 blocks), renewable anytime.

---

## Lifecycle Overview

1. **User registers** by calling `register-user` and paying the storage fee.
2. User gets access to password features like `store-password`, `get-password`, `update-password`, etc.
3. Passwords are **encrypted on the client side** before being sent to the contract.
4. Each action is **logged** for security auditing.
5. Subscription must be **renewed** periodically to retain access.
6. Admin can **disable contract** if needed.

---

##  Notes

- Passwords are not decrypted by the contract — only encrypted blobs are stored.
- IP logs are placeholder strings ("encrypted-hash") and should be implemented securely off-chain.
- Filtering logic in `delete-password`'s helper function is simplified — implement proper filtering in production.

---

## License

MIT License

---

## Author

**Aaronpil1**  
Built on the Stacks blockchain with Clarity 
