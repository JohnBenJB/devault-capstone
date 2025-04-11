
# DeVault

A decentralized digital vault for secure storage and verification of important documents, built as a capstone project.

## 🚀 Features

- 🔐 Decentralized document storage  
- 🛡️ Immutable proof of authenticity via blockchain  
- 🧠 Smart contract-based access control  
- 🧾 On-chain audit trail and access logs  

## 🧱 Stack

- **Internet Computer Protocol (ICP)** – decentralized backend  
- **Motoko** – smart contracts for access, verification, and data integrity  
- **React + TailwindCSS** – modern and responsive frontend  
- **Web3.Storage / IPFS** – distributed file storage  
- **Internet Identity** – decentralized user authentication  

## 🧭 Getting Started

1. Clone the repo  
   ```bash
   git clone https://github.com/your-username/devault.git
   cd devault
   ```

2. Install frontend dependencies  
   ```bash
   cd frontend
   npm install
   ```

3. Start the ICP local environment  
   ```bash
   dfx start --background
   ```

4. Deploy the canisters  
   ```bash
   dfx deploy
   ```

5. Run the frontend  
   ```bash
   npm run dev
   ```

---

## 📁 Project Structure

```
Devault-Capstone/
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── App.jsx
│   │   └── main.jsx
│   └── tailwind.config.js
├── backend/
│   ├── src/
│   │   └── devault_backend/
│   │       ├── main.mo
│   │       └── types.mo
│   └── dfx.json
├── README.md
├── .gitignore
└── package.json
```

---

## 🧪 Boilerplate Code

### 📜 `main.mo` (Motoko Canister Placeholder)

```motoko
actor DeVault {
  public func greet(name : Text) : async Text {
    return "Hello, " # name # "! Welcome to DeVault.";
  }
}
```

---

### 💻 `App.jsx` (Starter UI)

```jsx
import React from "react";

export default function App() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <h1 className="text-3xl font-bold text-gray-800">Welcome to DeVault</h1>
    </div>
  );
}
```

---

## 📌 License

MIT

---
