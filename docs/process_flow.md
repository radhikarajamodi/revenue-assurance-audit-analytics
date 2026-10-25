## Revenue-cycle process and evidence

```mermaid
flowchart LR
  A[Customer order and approved prices] --> B[Sales order and lines]
  B --> C[Warehouse dispatch and carrier evidence]
  C --> D[Shipment-linked invoice]
  D --> E[Recognized credit sale: Dr AR / Cr revenue]
  E --> F[GL interface and period posting]
  D --> G[AR subledger]
  H[Bank receipt and remittance] --> I[Cash application validation]
  I --> G
  I --> J[Dr cash / Cr AR]
  H --> K[Unapplied advance: Cr deposits]
  L[Return receipt and independent credit approval] --> M[Dr sales returns / Cr AR]
  M --> G
  G --> N[AR rollforward, aging and GL reconciliation]
  F --> N
  J --> N
  M --> N
  O[Roles, permissions and activity logs] --> P[Access / duties / approval testing]
  Q[Manual journal and independent approval] --> F
  N --> R[Exception workpapers and investigation]
  P --> R
  R --> S[Supported correction and control remediation]
```

Preventive controls: approved pricing, shipping support, duplicate blocks, constrained cash application, independent credit/manual journal approval and separation of billing/cash duties. Detective controls: daily interface reconciliation, month-end cutoff review, aging and access recertification. The app recommends remediation; it does not post corrections.
