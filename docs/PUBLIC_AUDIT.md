# Public audit

**Verdict: SAFE (accepted residual)**

Demonstration passwords were rotated and verified. They no longer authenticate. Default-branch history was squashed, and this tree does not contain the previous demonstration secrets.

GitHub still keeps the heads of pull requests 1–4 publicly fetchable. Those commits still contain the old demonstration passwords, the old hostname, and the D1 database id. The passwords are dead. Leaving those refs in place is Lewis's choice, and that residual is accepted.
