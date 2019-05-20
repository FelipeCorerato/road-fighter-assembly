; ###################################

; ###################################

; https://docs.microsoft.com/en-us/windows/desktop/inputdev/wm-keydown
; cor de fundo dos sprites #400080

.code

start:
    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
        
    invoke ExitProcess,eax