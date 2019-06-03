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
    percurso equ    102
    score    equ    103
    telavitoria equ 104

	CREF_TRANSPARENT  EQU 0800040h
	CREF_TRANSPARENT2 EQU 000FF00h

  ID_TIMER  equ 1
  TIMER_MAX equ 60

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

        hBmpSprites     dd 0
        hBmpCenario     dd 0
        hBmpPercurso    dd 0
        hBmpScore       dd 0
        hBmpTelaVitoria dd 0

        header_format_score_show db "%d", 0

        seed         dd 123212
        venceu       db 0
        pontos       dd 666666
        combustivel  dd 100

    .data?
        carstruct struct
            posX dd ?
            posY dd ? ; nao tem
            velY dd ?
        carstruct ends

        keystruct struct
            direita   db ?
            esquerda  db ?
            z         db ?
            x         db ?
        keystruct ends

        iTimer          dd ?
        posYbg          dd ?
        posYperc        dd ?
        delayMorreu     dd ?
        delaySpawn      dd ?
        delaySpawnCarro dd ?

        buffer db 300 dup(?) 
        hFont  dd ?

        jogador       carstruct <>
        truck         carstruct <>
        carro_inimigo carstruct <>
        teclas        keystruct <>

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

    invoke LoadBitmap, hInstance, percurso
    mov	hBmpPercurso, eax

    invoke LoadBitmap, hInstance, score
    mov	hBmpScore, eax

    invoke LoadBitmap, hInstance, telavitoria
    mov	hBmpTelaVitoria, eax

    invoke GetStockObject,DEVICE_DEFAULT_FONT
    mov hFont,eax

    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; cleanup & return to operating system

Collision proc sx:DWORD, sy:DWORD, sb:DWORD, sh:DWORD, qx:DWORD, qy:DWORD, qb:DWORD, qh:DWORD
	mov eax, qx
	add eax, qb

	mov ebx, sx
	add ebx, sb

	mov ecx, qy
	add ecx, qh

	mov edx, sy
	add edx, sh

	.if (sx < eax) && (ebx > qx) && (sy < ecx) && (edx > qy)
		return 1;
	.endif

	return 0
Collision endp

getrandom proc
  gerar:
    invoke  GetTickCount
    invoke  nseed, seed
    invoke  nrandom, 120 ;gera um numero random de 0 a 8
    ;geramos de 0 a 8 para que os numeros que nós queremos (1-7) se tornam equiprováveis
    mov seed, eax
    return eax
getrandom endp
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
        mov jogador.velY, 0

        mov truck.posX, 180
        mov truck.posY, 1000
        mov truck.velY, 10

        mov carro_inimigo.posX, 180
        mov carro_inimigo.posY, 330
        mov carro_inimigo.velY, 15

        mov posYbg, 0
        
        mov posYperc, 418
        mov delayMorreu, 0
        mov delaySpawn, 4
        mov delaySpawnCarro, 2

        invoke SetTimer, hWin, ID_TIMER, TIMER_MAX, NULL
        mov iTimer, eax

    .elseif uMsg == WM_TIMER
        invoke KillTimer, hWin, iTimer

        mov eax, pontos
        sbb eax, 10
        mov pontos, eax

        .if delayMorreu == 0
	        .if teclas.direita == 1
	        	.if jogador.posX < 278
	            	mov eax, jogador.posX
	            	add eax, 5
	           		mov jogador.posX, eax
	           	.endif
	           	.if jogador.posX > 273 && jogador.velY > 1
	           		mov delayMorreu, 20
	           		mov jogador.velY, 0

	           		mov eax, pontos
       				sbb eax, 1000
        			mov pontos, eax
	           	.endif
	        .endif

	        .if teclas.esquerda == 1
	        	.if jogador.posX > 153
	           		mov eax, jogador.posX
	            	sbb eax, 5
	            	mov jogador.posX, eax
	            .endif
	            .if jogador.posX < 158 && jogador.velY > 1
	           		mov delayMorreu, 20
	           		mov jogador.velY, 0

	           		mov eax, pontos
       				sbb eax, 1000
        			mov pontos, eax
	           	.endif
	        .endif
	     .else
	     	.if delayMorreu == 1
	     		mov jogador.posX, 220
        		mov jogador.posY, 330
	     	.endif

	     	mov eax, delayMorreu
	     	dec eax
	     	mov delayMorreu, eax
	     .endif

        .if teclas.z == 1 && delayMorreu == 0
        	.if jogador.velY < 20
        		mov eax, jogador.velY
            	add eax, 1
           		mov jogador.velY, eax
           	.endif
        .else
        	.if jogador.velY > 0
        		mov eax, jogador.velY
            	sbb eax, 1
           		mov jogador.velY, eax
           	.endif
        .endif

        .if teclas.x == 1 && delayMorreu == 0
        	.if jogador.velY < 30
        		mov eax, jogador.velY
            	add eax, 2
           		mov jogador.velY, eax
           	.endif
        .else
        	.if jogador.velY > 8
        		mov eax, jogador.velY
            	sbb eax, 1
           		mov jogador.velY, eax
           	.endif
        .endif

        ;desce o fundo
        mov eax, posYbg
        add eax, jogador.velY
        mov posYbg, eax
        ;--

        ;move o caminhao
        mov eax, jogador.velY
        .if truck.velY > eax
        	mov eax, truck.posY

        	mov ebx, truck.velY
        	sbb ebx, jogador.velY

        	sbb eax, ebx
        	mov truck.posY, eax
        .else
        	mov eax, truck.posY

        	mov ebx, jogador.velY
        	sbb ebx, truck.velY

        	add eax, ebx
        	mov truck.posY, eax
        .endif
        
        ;move carro inimigo
        mov eax, jogador.velY
        .if carro_inimigo.velY > eax
        	mov eax, carro_inimigo.posY

        	mov ebx, carro_inimigo.velY
        	sbb ebx, jogador.velY

        	sbb eax, ebx
        	mov carro_inimigo.posY, eax
        .else
        	mov eax, carro_inimigo.posY

        	mov ebx, jogador.velY
        	sbb ebx, carro_inimigo.velY

        	add eax, ebx
        	mov carro_inimigo.posY, eax
        .endif

        invoke Collision, truck.posX, truck.posY, 30, 64, jogador.posX, jogador.posY, 22, 32

        .if eax == 1 && delayMorreu == 0 ;qd ele colidir e estiver vivo entra aqui
        	mov delayMorreu, 20
	        mov jogador.velY, 0

	        mov eax, pontos
       		sbb eax, 1000
        	mov pontos, eax
        .endif
        ;--

        invoke Collision, carro_inimigo.posX, carro_inimigo.posY, 22, 32, jogador.posX, jogador.posY, 22, 32

        .if eax == 1 && delayMorreu == 0 ;qd ele colidir e estiver vivo entra aqui
        	mov delayMorreu, 20
	        mov jogador.velY, 0

	        mov eax, pontos
       		sbb eax, 1000
        	mov pontos, eax
        .endif

        .if posYbg > 448
        	;anda o carrinho do percurso
        	mov eax, posYperc
        	sbb eax, 8
        	mov posYperc, eax

        	;---------------------------

        	;coloca o cenario referencia de volta a 0
        	mov eax, 0
        	mov posYbg, eax
        	;----------------------------------------
        	.if delaySpawn == 0
        		.if truck.posY > 448
	        		mov delaySpawn, 2

	        		mov ecx, 0
					sbb ecx, 32
	        		mov truck.posY, ecx

	        		invoke getrandom
	        		add eax, 153
	        		mov truck.posX, eax 
	        	.endif
        	.else
	        	mov eax, delaySpawn
	        	dec eax
	        	mov delaySpawn, eax
	        .endif

            .if delaySpawnCarro == 0
        		.if carro_inimigo.posY > 448
	        		mov delaySpawnCarro, 2

	        		mov ecx, 0
					sbb ecx, 32
	        		mov carro_inimigo.posY, ecx

	        		invoke getrandom
	        		add eax, 153
	        		mov carro_inimigo.posX, eax 
	        	.endif
        	.else
	        	mov eax, delaySpawnCarro
	        	dec eax
	        	mov delaySpawnCarro, eax
	        .endif
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

    .if posYperc <= 2 || venceu == 1
		mov venceu, 1

        invoke  SelectObject, memDC, hBmpTelaVitoria
		mov	hOld, eax
		
		invoke TransparentBlt,hDC,0,0,512,448,memDC,0,0,500,375, CREF_TRANSPARENT2
    .else
	;;Percurso
    invoke  SelectObject, memDC, hBmpPercurso
	mov	hOld, eax

    invoke TransparentBlt, hDC, 0, 0, 64, 448, memDC, 0, 0, 32, 224, CREF_TRANSPARENT

    ;carrinhoperc
	invoke  SelectObject, memDC, hBmpSprites
	mov	hOld, eax
	
	invoke TransparentBlt,hDC,24,posYperc,16,30,memDC,5,36,8,15, CREF_TRANSPARENT
    ;-------
    ;cenario

    invoke  SelectObject, memDC, hBmpCenario
	mov	hOld, eax

	mov ecx, posYbg
	sbb ecx, 448
    invoke TransparentBlt, hDC, 64, ecx, 320, 448, memDC, 0, 0, 160, 224, CREF_TRANSPARENT

    invoke  SelectObject, memDC, hBmpCenario
	mov	hOld, eax

    invoke TransparentBlt, hDC, 64, posYbg, 320, 448, memDC, 0, 0, 160, 224, CREF_TRANSPARENT

    .if posYperc <= 10
  		invoke  SelectObject, memDC, hBmpSprites
		mov	hOld, eax
		
		invoke TransparentBlt,hDC,153,posYbg,146,18,memDC,69,62,64,8, CREF_TRANSPARENT
  	.endif

    ;-------
    ;Placar de pontuacao

    invoke SelectObject, memDC, hBmpScore
    mov hOld, eax

    invoke TransparentBlt, hDC, 384, 0, 126, 448, memDC, 0, 0, 63, 224, CREF_TRANSPARENT

    ;-------
    ;Pontuacao

    invoke SelectObject, memDC, hFont
    invoke SetTextColor, memDC, 0
    invoke SetBkColor,   memDC, 0FFFFFFh
    
    invoke wsprintfA, ADDR buffer, ADDR header_format_score_show, pontos
    invoke ExtTextOutA, hDC, 400, 82, ETO_CLIPPED, NULL, ADDR buffer, eax, NULL    

    ;-------
    ;Jogador
    .if delayMorreu == 0
		invoke  SelectObject, memDC, hBmpSprites
		mov	hOld, eax
		
		invoke TransparentBlt,hDC,jogador.posX,jogador.posY,22,32,memDC,3,3,11,16, CREF_TRANSPARENT
	.elseif delayMorreu < 10
		invoke  SelectObject, memDC, hBmpSprites
		mov	hOld, eax
		
		mov ecx, jogador.posX
		sbb ecx, 2
		invoke TransparentBlt,hDC,ecx,jogador.posY,30,32,memDC,59,35,15,16, CREF_TRANSPARENT
	.else
		invoke  SelectObject, memDC, hBmpSprites
		mov	hOld, eax
		
		invoke TransparentBlt,hDC,jogador.posX,jogador.posY,22,26,memDC,45,36,11,13, CREF_TRANSPARENT		
	.endif

	;----------
	;caminhao
		.if truck.posY < 450
			invoke  SelectObject, memDC, hBmpSprites
			mov	hOld, eax
		
			invoke TransparentBlt,hDC,truck.posX,truck.posY,30,64,memDC,70,82,15,32, CREF_TRANSPARENT
		.endif
	;-------------

    ;----------
	;carro_inimigo
		.if carro_inimigo.posY < 450
			invoke  SelectObject, memDC, hBmpSprites
			mov	hOld, eax
		
			invoke TransparentBlt,hDC,carro_inimigo.posX,carro_inimigo.posY,22,32,memDC,6,101,11,16, CREF_TRANSPARENT
		.endif
	;-------------
    .endif
	
	invoke SelectObject, hDC, hOld
	
	invoke DeleteDC, memDC

	return 0

Paint_Proc endp
end start