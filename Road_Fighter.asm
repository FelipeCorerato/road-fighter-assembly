; #########################################################################
;
;             GENERIC.ASM is a roadmap around a standard 32 bit 
;              windows application skeleton written in MASM32.
;
; #########################################################################

;           Assembler specific instructions for 32 bit ASM code

      .386                   ; minimum processor needed for 32 bit
      .model flat, stdcall   ; FLAT memory model & STDCALL calling
      option casemap :none   ; set code to case sensitive

; #########################################################################

      ; ---------------------------------------------
      ; main include file with equates and structures
      ; ---------------------------------------------
      include \masm32\include\windows.inc

      ; -------------------------------------------------------------
      ; In MASM32, each include file created by the L2INC.EXE utility
      ; has a matching library file. If you need functions from a
      ; specific library, you use BOTH the include file and library
      ; file for that library.
      ; -------------------------------------------------------------
      include \masm32\include\masm32.inc
      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc
      include \masm32\include\gdi32.inc
      include \masm32\include\msimg32.inc
      

      includelib \masm32\lib\masm32.lib
      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib
      includelib \masm32\lib\gdi32.lib
      includelib \masm32\lib\msimg32.lib

; #########################################################################

; ------------------------------------------------------------------------
; MACROS are a method of expanding text at assembly time. This allows the
; programmer a tidy and convenient way of using COMMON blocks of code with
; the capacity to use DIFFERENT parameters in each block.
; ------------------------------------------------------------------------

      ; 1. szText
      ; A macro to insert TEXT into the code section for convenient and 
      ; more intuitive coding of functions that use byte data as text.

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      ; 2. m2m
      ; There is no mnemonic to copy from one memory location to another,
      ; this macro saves repeated coding of this process and is easier to
      ; read in complex code.

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

      ; 3. return
      ; Every procedure MUST have a "ret" to return the instruction
      ; pointer EIP back to the next instruction after the call that
      ; branched to it. This macro puts a return value in eax and
      ; makes the "ret" instruction on one line. It is mainly used
      ; for clear coding in complex conditionals in large branching
      ; code such as the WndProc procedure.

      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

; ----------------------------------------------------------------------
; Prototypes are used in conjunction with the MASM "invoke" syntax for
; checking the number and size of parameters passed to a procedure. This
; improves the reliability of code that is written where errors in
; parameters are caught and displayed at assembly time.
; ----------------------------------------------------------------------

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD
        
        Paint_Proc	PROTO :DWORD, :DWORD

; #########################################################################


; definindo as constantes
.Const
	sprites  equ	100
    cenario  equ	101

	CREF_TRANSPARENT  EQU 0800040h
	CREF_TRANSPARENT2 EQU 0FF0000h

  ID_TIMER  equ 1
  TIMER_MAX equ 30




; ------------------------------------------------------------------------
; This is the INITIALISED data section meaning that data declared here has
; an initial value. You can also use an UNINIALISED section if you need
; data of that type [ .data? ]. Note that they are different and occur in
; different sections.
; ------------------------------------------------------------------------

    .data
        szDisplayName db "Road Fighter",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0

        hBmpSprites  dd 0
        hBmpCenario  dd 0

    .data?
        carstruct struct
            posX dd ?
            posY dd ? ; nao tem
            velX dd ?
            velY dd ?
        carstruct ends

        keystruct struct
            direita   db ?
            esquerda  db ?
            z         db ?
            x         db ?
        keystruct ends

        iTimer         dd ?

        jogador carstruct <>
        teclas  keystruct <>

; #########################################################################

; ------------------------------------------------------------------------
; This is the start of the code section where executable code begins. This
; section ending with the ExitProcess() API function call is the only
; GLOBAL section of code and it provides access to the WinMain function
; with the necessary parameters, the instance handle and the command line
; address.
; ------------------------------------------------------------------------

    .code

; -----------------------------------------------------------------------
; The label "start:" is the address of the start of the code section and
; it has a matching "end start" at the end of the file. All procedures in
; this module must be written between these two.
; -----------------------------------------------------------------------

start:
    mov teclas.direita, 0
    mov teclas.esquerda, 0
    mov teclas.x, 0
    mov teclas.z, 0

    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax
    
    invoke LoadBitmap, hInstance, sprites
    mov	hBmpSprites, eax
    
    invoke LoadBitmap, hInstance, cenario
    mov	hBmpCenario, eax

    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; cleanup & return to operating system

; #########################################################################

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        ;====================
        ; Put LOCALs on stack
        ;====================

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG

        LOCAL Wwd  :DWORD
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Primeiro_Class"

        ;==================================================
        ; Fill WNDCLASSEX structure with required variables
        ;==================================================

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                               or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; instance handle
        mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; window class name
          invoke LoadIcon,hInst,500    ; icon ID   ; resource icon
        mov wc.hIcon,          eax
          invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; register the window class

        ;================================
        ; Centre window at following size
        ;================================

        mov Wwd, 530
        mov Wht, 490

        invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
        invoke TopXY,Wwd,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
        invoke TopXY,Wht,eax
        mov Wty, eax

        ; ==================================
        ; Create the main application window
        ; ==================================
        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_OVERLAPPEDWINDOW,
                              Wtx,Wty,Wwd,Wht,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke LoadMenu,hInst,600                 ; load resource menu
        invoke SetMenu,hWnd,eax                   ; set it to main window

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

      ;===================================
      ; Loop until PostQuitMessage is sent
      ;===================================

    StartLoop:
      invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
      cmp eax, 0                                  ; exit if GetMessage()
      je ExitLoop                                 ; returns zero
      invoke TranslateMessage, ADDR msg           ; translate it
      invoke DispatchMessage,  ADDR msg           ; send it to message proc
      jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

	LOCAL Ps 	:PAINTSTRUCT
	LOCAL hDC	:DWORD  ; handle do dispositivo (tela)

; -------------------------------------------------------------------------
; Message are sent by the operating system to an application through the
; WndProc proc. Each message can have additional values associated with it
; in the two parameters, wParam & lParam. The range of additional data that
; can be passed to an application is determined by the message.
; -------------------------------------------------------------------------

    .if uMsg == WM_COMMAND
    ;----------------------------------------------------------------------
    ; The WM_COMMAND message is sent by menus, buttons and toolbar buttons.
    ; Processing the wParam parameter of it is the method of obtaining the
    ; control's ID number so that the code for each operation can be
    ; processed. NOTE that the ID number is in the LOWORD of the wParam
    ; passed with the WM_COMMAND message. There may be some instances where
    ; an application needs to seperate the high and low words of wParam.
    ; ---------------------------------------------------------------------
    
    ;======== menu commands ========

        .if wParam == 1000
            invoke SendMessage,hWin,WM_SYSCOMMAND,SC_CLOSE,NULL
        .elseif wParam == 1900
            szText TheMsg,"Teste"
            invoke MessageBox,hWin,ADDR TheMsg,ADDR szDisplayName,MB_OK
        .endif

    ;====== end menu commands ======
    .elseif uMsg == WM_PAINT

	    invoke BeginPaint, hWin, ADDR Ps
	    mov	hDC, eax
	
	    invoke  Paint_Proc, hWin, hDC
	
	    invoke EndPaint, hWin, ADDR Ps


    .elseif uMsg == WM_CREATE
    ; --------------------------------------------------------------------
    ; This message is sent to WndProc during the CreateWindowEx function
    ; call and is processed before it returns. This is used as a position
    ; to start other items such as controls. IMPORTANT, the handle for the
    ; CreateWindowEx call in the WinMain does not yet exist so the HANDLE
    ; passed to the WndProc [ hWin ] must be used here for any controls
    ; or child windows.
    ; --------------------------------------------------------------------
        mov jogador.posX, 220
        mov jogador.posY, 330

        invoke SetTimer, hWin, ID_TIMER, TIMER_MAX, NULL
        mov iTimer, eax

    .elseif uMsg == WM_TIMER
        invoke KillTimer, hWin, iTimer

        .if teclas.direita == 1
            mov eax, jogador.posX
            add eax, 3
            mov jogador.posX, eax
        .endif

        .if teclas.esquerda == 1
            mov eax, jogador.posX
            sbb eax, 3
            mov jogador.posX, eax
        .endif

        invoke InvalidateRect, hWin, NULL, TRUE

        invoke SetTimer, hWin, ID_TIMER, TIMER_MAX, NULL
        mov iTimer, eax


    .elseif uMsg == WM_CLOSE
    ; -------------------------------------------------------------------
    ; This is the place where various requirements are performed before
    ; the application exits to the operating system such as deleting
    ; resources and testing if files have been saved. You have the option
    ; of returning ZERO if you don't wish the application to close which
    ; exits the WndProc procedure without passing this message to the
    ; default window processing done by the operating system.
    ; -------------------------------------------------------------------

    .elseif uMsg == WM_KEYDOWN
        .if wParam == VK_LEFT
            mov teclas.esquerda, 1
        .endif

        .if wParam == VK_RIGHT
            mov teclas.direita, 1
        .endif

        .if wParam == 58h
            mov teclas.x, 1
        .endif

        .if wParam == 5Ah
            mov teclas.z, 1
        .endif

    .elseif uMsg == WM_KEYUP
        .if wParam == VK_LEFT
            mov teclas.esquerda, 0
        .endif

        .if wParam == VK_RIGHT
            mov teclas.direita, 0
        .endif

        .if wParam == 58h
            mov teclas.x, 0
        .endif

        .if wParam == 5Ah
            mov teclas.z, 0
        .endif


    .elseif uMsg == WM_DESTROY
    ; ----------------------------------------------------------------
    ; This message MUST be processed to cleanly exit the application.
    ; Calling the PostQuitMessage() function makes the GetMessage()
    ; function in the WinMain() main loop return ZERO which exits the
    ; application correctly. If this message is not processed properly
    ; the window disappears but the code is left in memory.
    ; ----------------------------------------------------------------
        invoke KillTimer, hWin, iTimer
        invoke PostQuitMessage,NULL
        return 0 
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam
    ; --------------------------------------------------------------------
    ; Default window processing is done by the operating system for any
    ; message that is not processed by the application in the WndProc
    ; procedure. If the application requires other than default processing
    ; it executes the code when the message is trapped and returns ZERO
    ; to exit the WndProc procedure before the default window processing
    ; occurs with the call to DefWindowProc().
    ; --------------------------------------------------------------------

    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

    ; ----------------------------------------------------
    ; This procedure calculates the top X & Y co-ordinates
    ; for the CreateWindowEx call in the WinMain procedure
    ; ----------------------------------------------------

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

; ########################################################################


Paint_Proc proc hWin:DWORD, hDC:DWORD

	LOCAL hOld:DWORD
	LOCAL memDC:DWORD

	invoke  CreateCompatibleDC, hDC
	mov	memDC, eax

    invoke  SelectObject, memDC, hBmpCenario
	mov	hOld, eax

    invoke TransparentBlt, hDC, 0, 0, 512, 448, memDC, 0, 0, 256, 224, CREF_TRANSPARENT
	
	invoke  SelectObject, memDC, hBmpSprites
	mov	hOld, eax
	
	invoke TransparentBlt,hDC,jogador.posX,jogador.posY,22,32,memDC,3,3,11,16, CREF_TRANSPARENT
	
	invoke SelectObject, hDC, hOld
	
	invoke DeleteDC, memDC

	return 0

Paint_Proc endp

Speed_Thread proc USES ecx Param:DWORD

    invoke WaitForSingleObject,hEventStart, 10 ;tempo em ms

	.IF eax == WAIT_TIMEOUT	
        invoke PostMessage,hWnd,WM_FINISH,NULL,NULL
        jmp   Speed_Thread
    .ENDIF

    ret
Speed_Thread endp

end start
