# Tasks: replace

- [x] 1. Copy the shared Windows code into `source/win/` with its tests
  - _Requirements: 1.2, 5.1, 5.2_
- [x] 2. Parse the operands and `/A /P /R /S /W /U`; replace's usage errors with status 11
  - _Requirements: 5.1, 5.2, 5.3, 5.5_
- [x] 3. Full paths for messages, physical directories for the same-file check
  - _Requirements: 2.5, 5.4_
- [x] 4. Source names and the source and destination checks
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
- [x] 5. Replace: targets in `/S` order, `/U`, onto-itself check, read-only and `/R`, summary
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
- [x] 6. Add (`/A`) and its summary
  - _Requirements: 3.1, 3.2_
- [x] 7. `/P` questions and the `/W` key wait through a `sh` child
  - _Requirements: 4.1, 4.2, 4.3_
- [x] 8. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
