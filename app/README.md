# Catn Control

One window that shows and controls every Catn script on your accounts.

## Start it
Double-click **Catn Control.cmd** (or the desktop shortcut). It opens in its own Edge window.
Sign in once with your Firebase login and the project's Web API key (Firebase → Project settings → General).

## Link an account
In any Catn script, open **Settings → Menu** and turn on **Allow Catn Control**. That turns it on for every
account on that PC. It is off by default, so nobody else who runs Catn Hub can be controlled.

## How it works
- Every Catn window sends its menu and current values to `menus/<account>/<window>`.
- The app writes orders to `orders/<account>/<id>`. Firebase only accepts them from the owner's login.
- The script applies an order through the control's own setter (exactly like a click) and replies in `acks/`.
  The app shows pending, then ✓ or ✗ with the reason, and cleans both up.
- Orders older than the script's start or older than 60 s are ignored, so a hop or rejoin never replays.

## Firebase rules
```json
{
  "rules": {
    ".read": true,
    ".write": false,
    "accounts": { ".write": true },
    "boards":   { ".write": true },
    "menus":    { ".write": true },
    "acks":     { ".write": true },
    "orders":   { ".write": "auth != null && auth.uid === '<your uid>'" }
  }
}
```

## Tests
`node app/core.test.js` and `python tests/bridge_test.py` (needs `pip install lupa`).
Open `catn-control.html?demo` to try the app with made-up data.
