#include <efi.h>
#include <efilib.h>

CHAR16* strs[] = { L"xi ", L"wo ", L"gai ", L"zen ", L"me ", L"bang ", L"ne " };

UINT32 xorshift(UINT32 x) {
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return x;
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  InitializeLib(ImageHandle, SystemTable);
  _cast64_efi_call4(BS->SetWatchdogTimer, 0, 0, 0, NULL);
  _cast64_efi_call1(ST->ConOut->ClearScreen, ST->ConOut);
  UINT32 state = 0;
  UINT32 rand = 1010903229;
  for (; ;) {
    Output(strs[state]);
    if (!((rand = xorshift(rand)) & 3)) state = !state;
    else if (state && ++state == 7) state = 0;
    _cast64_efi_call1(BS->Stall, 200000);
  }
}
