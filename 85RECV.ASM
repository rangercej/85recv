~A86 will remove error messages if you leave this line in.~
;****************************************************************************
;**
;** 85RECV.ASM - Assembler recode of 85RECV.PAS and TI85.PAS
;**
;** Who cares what version this is??? If you do...look at the screen messages
;** - that'll keep the latest version...
;**
;** Thanks to Gull (gull@cyberspace.org) for sending the original pascal port
;** read/writes to me and Per Finander (pfimdt@hvdc.hv.se) for writing the
;** original Pascal routines. Also to Magnus Hagander (mha@algonet.se) for
;** bits of advice, and finally to Robert Taylor (100125.1671@compuserve.com)
;** for his C++ version of the code (which is virtually totally different, so
;** I'm going to have to re-write some routines). Thanks.
;**
;** If I've missed anyone else out, then sorry, but thanks anyway ;-) - and if
;** anyone who has contributed somehow reads this, then I'll buy 'em a drink
;** if I meet 'em IRL...(famous last words...)
;**
;** Copyright notes:
;** As far as I know, Per Finander hasn't copyrighted his pascal routines, and
;** Robert Taylor his C++ code, but to be on the safe side...
;**       Pascal Versions of GETPORT, SETPORT, SEND, RECEIVE and INITPORT
;**                 (c) 1995 Per Finander
;**       C++ Versions of the other COMMS routines (c) 1995 Robert Taylor
;**       Assembler conversions (c) 1995 By Chris Johnson
;**       85RECV (c) 1995 by Chris Johnson
;**
;****************************************************************************
;** Here goes...
;****************************************************************************

cseg      segment   para        public  'CODE'
          org       100h
          assume    cs:cseg,ds:cseg
start:
          jmp init

;Copyright - if someone does TYPE 85RECV.COM - and also a bit of useless info :)
cp        db        0dh,0ah,'** 85RECV - Assembler version - C.Johnson 1995 **',1ah

;Comm port addresses (fetch from 0:0400h)
portaddr  dw        ?         ; The com port address...see init for details

; This next bit is the file header definition.
head_len  dw        08h+03h+2ah+02h
f_head    db        '**TI85**',1ah,0ch,00h
fcomment  db        'Created by 85RECV - C.Johnson 1995        '
datasize  dw        ?

;Var type extensions (.85?)
codes     db        'NCVVLLMMKKERSDDDDIPR RRRRRRR                  '

;Var type table - Each entry is 5 bytes length - padding with nulls if need be
names     db        'REAL',0h
          db        'CPLX',0h
          db        'VECTR','VECTR'
          db        'LIST',0h,'LIST',0h
          db        'MATRX','MATRX'
          db        'CONST','CONST'
          db        'EQU',0h,0h
          db        'RANGE'
          db        'STRNG'
          db        'GDB',0h,0h,'GDB',0h,0h,'GDB',0h,0h,'GDB',0h,0h
          db        'PICT',0h
          db        'PRGM',0h
          db        'RANGE'
          db        '?????'
          db        'RANGE','RANGE','RANGE','RANGE','RANGE','RANGE','RANGE'
          db        '?????????????????????????????????????????????????????'

;Screen Messages!
crlf      db        0Dh,0Ah,'$'
dash_div  db        '-------------------------------------------------$'
titles    db        '85RECV - Assembler Version 0.7 - C.Johnson 1995$'
connect   db        'Please connect TI-85 and hit ENTER...$'
pause     db        'Waiting for TI-85...$'
fetch     db        'Receiving: $'
colon     db        ':$'
adot      db        '.$'                          ; These two (the . and the
star      db        '*$'                          ; * ) are for debugging.
bytes     db        ' bytes:$'

finish    db        'Finished receive.$'
stats1    db        'Received $'
stats2    db        ' vars.$'

;Filename template
handle    dw        0                   ; File handle
fname     db        'TI.85'             ; ASCIIZ file spec...
suff      db        ?,00h               ; ...and here.

;File error messages
err_mess  db        'Error!$'

;General variables
b_tmp     db        ?
w_tmp     dw        ?
d_tmp     dd        ?

;COMM Port routines

;**************************************************************************
;** Setport
setport:            ; set/reset RTS/DTR   in -> AL: Bits  out -> nothing
          push      ax
          push      dx                  
          and       al,03h
          mov       dx,[portaddr]
          add       dx,4
          out       dx,al
          pop       dx
          pop       ax
          ret

;**************************************************************************
;** Getport
getport:            ; read CTS/DSR        in -> nothing  out -> al: Byte read
          push      dx
          push      cx
          mov       dx,[portaddr]
          add       dx,6
          in        al,dx
          and       al,48
          mov       cl,4                ; Divide by 16
          shr       al,cl               
          pop       cx
          pop       dx
          
          push      ax                  ; In case of timeout, stop program by
          mov       ah,01h              ; user hitting key.
          int       16h
          jz        gp1
          pop       ax
          int       20h
gp1:      pop       ax
          
          ret

;**************************************************************************
;** Send
send:               ; Send a byte to the '85   in -> ah: byte to send
          push      ax
          push      cx
          mov       [b_tmp],ah
          mov       al,3                ; Setport (3)
          call      setport

          mov       cx,8                ; for bitloop:=0 to 7 do begin
s1:       call      getport             ;   while getport<>3 do nothing
          cmp       al,3
          jne       s1

          and       ah,1                ;   if (B and 1)=0 then begin
          cmp       ah,0
          jne       s2
          mov       al,1                ;     setport (1)
          call      setport
s3:       call      getport             ;     while (getport AND 2)=2 do nowt
          and       al,2
          cmp       al,2
          je        s3
          mov       al,3                ;     setport (3)
          call      setport
s4:       call      getport             ;     while (getport AND 2)=0 do nowt
          and       al,2
          cmp       al,0
          je        s4
          jmp       s5                  ;   end else begin
s2:       mov       al,2                ;     setport (2)
          call      setport
s6:       call      getport             ;     while (getport AND 1)=1 do nowt
          and       al,1
          cmp       al,1
          je        s6
          mov       al,3                ;     setport (3)
          call      setport
s7:       call      getport             ;     while (getport AND 1)=0 do nowt
          and       al,1
          cmp       al,0
          je        s7                  ;   end (else)
s5:       mov       ah,[b_tmp]          ;   B:=B div 2
          shr       ah,1
          mov       [b_tmp],ah
          loop      s1                  ; end (for)
          pop       cx
          pop       ax
          call      putadot
          call      delay
          ret

;**************************************************************************
;** Receive
receive:            ; Receive from '85   in -> nowt   out -> ah -> byte got
          push      ax
          push      bx
          push      cx
          push      dx
          mov       dh,1                ; CurrentBit:=1
          mov       bh,0                ; B:=0
          mov       al,3                ; setport (3)
          call      setport
          mov       cx,8                ; for bitloop:=0 to 7 do begin

r1:       call      getport             ;   while getport=3 do nothing
          cmp       al,3
          je        r1
          call      getport             ;   if getport=1 then begin
          cmp       al,1
          jne       r2
          or        bh,dh               ;     B:=B or currentbit
          mov       al,1                ;     SetPort (1)
          call      setport
r3:       call      getport             ;     while (getport AND 2)=0 do nowt
          and       al,2
          cmp       al,0
          je        r3
          jmp       r4                  ;   end else begin
r2:       mov       al,2                ;     setport (2)
          call      setport
r5:       call      getport             ;     while (getport AND 1)=0 do nowt
          and       al,1
          cmp       al,0
          je        r5
                                        ;   end
r4:       mov       al,3                ;   setport (3)
          call      setport
;r6:       call      getport             ;   while getport<>3 do nothing
;          cmp       al,3
;          jne       r6
          shl       dh,1                ;   currentbit:=currentbit*2
          loop      r1                  ; end
          
          mov       [b_tmp],bh          ; Receive:=B
          pop       dx          
          pop       cx
          pop       bx
          pop       ax
          mov       ah,[b_tmp]          ; the rest of Receive:=B :-)
          call      putdot
          call      delay
          ret

;**************************************************************************
;** Initport - Call before ANYTHING else (there must be a much shorter way...)
initport: push      ax
          push      dx
          mov       dx,[portaddr]       ; A bunch of port[portaddr+?]:=? :)
          add       dx,1
          mov       al,0
          out       dx,al
          mov       dx,[portaddr]
          add       dx,2
          mov       al,1
          out       dx,al
          mov       dx,[portaddr]
          add       dx,3
          mov       al,0
          out       dx,al
          mov       dx,[portaddr]
          add       dx,4
          mov       al,3
          out       dx,al
          mov       dx,[portaddr]
          add       dx,5
          mov       al,96
          out       dx,al
          mov       dx,[portaddr]
          add       dx,6
          mov       al,50
          out       dx,al
          mov       dx,[portaddr]
          add       dx,7
          mov       al,0                
          out       dx,al
          mov       al,3                ; Setport (3)
          call      setport
          pop       dx
          pop       ax
          ret

; Robs C++ routines (converted)...
;**************************************************************************
;** Read_WhiteStatus -> async_CTS_status
read_whitestatus:                       ; In -> Nothing    Out -> al: status
          push      cx
          push      dx                  
          mov       dx,[portaddr]
          add       dx,6
          in        al,dx
          mov       cl,4
          shr       al,cl
          pop       dx
          pop       cx
          
          push      ax                  ; In case of timeout, stop program by
          mov       ah,01h              ; user hitting key.
          int       16h
          jz        rws1
          pop       ax
          int       20h
rws1:     pop       ax
          
          ret

;**************************************************************************
;** Read_RedStatus -> async_DSR_status
read_redstatus:                         ; In -> Nothing    Out -> al: status
          push      cx
          push      dx                  
          mov       dx,[portaddr]
          add       dx,6
          in        al,dx
          mov       cl,5
          shr       al,cl
          pop       dx
          pop       cx
          
          push      ax                  ; In case of timeout, stop program by
          mov       ah,01h              ; user hitting key.
          int       16h
          jz        rrs1
          pop       ax
          int       20h
rrs1:     pop       ax
          
          ret

;**************************************************************************
;** Set_RedStatus -> async_set_RTS
set_redstatus:                          ; In -> al: status  Out -> Nothing
          push      bx
          push      dx
          mov       bl,al
          mov       dx,[portaddr]
          add       dx,4
          in        al,dx
          cmp       bl,1
          jne       srs1
          or        al,2
          jmp       srs2
srs1:     and       al,2
srs2:     out       dx,al
          pop       dx
          pop       bx
          ret

;**************************************************************************
;** Set_WhiteStatus -> async_set_DTR
set_whitestatus:                          ; In -> al: status  Out -> Nothing
          push      bx
          push      dx
          mov       bl,al
          mov       dx,[portaddr]
          add       dx,4
          in        al,dx
          cmp       bl,1
          jne       srs1
          or        al,1
          jmp       srs2
sws1:     and       al,1
sws2:     out       dx,al
          pop       dx
          pop       bx
          ret
          
;**************************************************************************
;** Read_ByteFromLink
state     db        0
ibyte     db        0
Read_bytefromlink:                      ; In -> Nothing    out -> Ah: Byte read
                                        ; Others:  bit: [ibyte], State: [state]
                                        ;          w_status: bh, r_status: bl
          push      ax
          push      bx
          push      cx
          push      dx
          
          mov       cx,8                ; for (bit=0; bit<8; bit++) {

rbfl1:    call      read_whitestatus    ;   do { W_Status=Read_WhiteStatus
          mov       bh,al
          call      read_redstatus      ;        R_Status=Read_RedStatus
          mov       bl,al
          mov       dh,bh               ;   } while w_status==1 && r_status==1
          and       dh,bl
          cmp       dh,1
          je        rbfl1

          cmp       bh,1                ;   if w_status==0 {
          jne       rbfl2
          mov       al,0                ;     set_redstatus (0)
          call      set_redstatus
rbfl3:    call      read_whitestatus    ;     do { w_status=read_whitestatus
          mov       bh,al
          call      read_redstatus      ;          r_status=read_redstatus 
          mov       bl,al
          cmp       bh,0                ;     } while (!(w_status=1 & 
          jne       rbfl3               ;                     r_status=0))
          cmp       bl,1
          jne       rbfl3
          mov       [state],1           ;     State=1
          jmp       rbfl4               ;   } else {
rbfl2:    mov       al,0                ;     set_whitestatus (0)
          call      set_whitestatus
rbfl5:    call      read_whitestatus    ;     do { w_status=read_whitestatus
          mov       bh,al
          call      read_redstatus      ;          r_status=read_redstatus
          mov       bl,al
          cmp       bh,1                ;     } while (!(w_status=0 & 
          jne       rbfl5               ;                     r_status=1))
          cmp       bl,0
          jne       rbfl5
          mov       [state],0           ;     State=0
                                        ;   }
rbfl4:    mov       al,1                ;   set_whitestatus (1)
          call      set_whitestatus
          mov       al,1                ;   set_redstatus (1)
          call      set_redstatus

          mov       dx,8                ;   Byte |= (state << bit)
          sub       dx,cx
          push      cx
          mov       cl,dl
          mov       [state],dl
          shr       dl,cl
          or        [ibyte],dl
          pop       cx
          loop      rbfl1               ; }

          pop       dx
          pop       cx
          pop       bx
          pop       ax
          mov       ah,[ibyte]
          ret
          
;All other routines:
;**************************************************************************
;** PutStar
putstar:  ret
          push      dx
          lea       dx,star
          call      putstring
          pop       dx
          ret

;**************************************************************************
;** PutDot
putdot:   ret
          push      dx
          lea       dx,colon
          call      putstring
          pop       dx
          ret

;**************************************************************************
;** PutADot
putadot:  ret
          push      dx
          lea       dx,adot
          call      putstring
          pop       dx
          ret

;**************************************************************************
;** Delay - make a delay (this is going to be fun...)
delay:
          push      dx
          push      cx
          push      ax
          mov       cx,45h
dloop:    xor       ax,dx
          xor       dx,ax
          loop      dloop
          pop       ax
          pop       cx
          pop       dx
          ret

;**************************************************************************
;** Showchar - show character
showchar: push      ax
          mov       ah,02h
          int       21h
          pop       ax
          ret

;**************************************************************************
;** printstring - print a string with newline
printstring:
          push      ax
          push      dx
          mov       ah,09h
          int       21h
          lea       dx,crlf
          int       21h
          pop       dx
          pop       ax
          ret

;**************************************************************************
;** putstring - as printstring but don't bother with a newline...
putstring:
          push      ax
          mov       ah,09h
          int       21h
          pop       ax
          ret

;**************************************************************************
;** dbintodec - convert doubleword dx:ax to decimal
;**    from PCPlus magazine
DBINTODEC:                              ; Requiers DX:AX - value, DI: Buffer
          push      dx
          push      ax
          push      bx
          push      si
          push      di
          mov       si,offset DBINTODECTABLE
          mov       cx,10               ;putative decimal counter
          xor       bx,bx
DBINTODEC1:                             ;clear significance pointer
          xor       bl,bl               ;clear the low byte
DBINTODEC2:
          cmp       dx,[si+2]           ;is the table entry too large ?
          jz        DBINTODEC4          ;probably - try the other side!
          jna       DBINTODEC5          ;yes - so jump
DBINTODEC3:
          sub       ax,[si]             ;reduce DX.AX by D[SI]
          sbb       dx,[si+2]
          inc       bl                  ;count this
          jmp       DBINTODEC2          ;repeat testing
DBINTODEC4:
          cmp       ax,[si]             ;is the table entry too large ?
          jnb       DBINTODEC3          ;no - jump to reduce
DBINTODEC5:
          push      ax                  ;save the residue
          push      dx
          cmp       cx,1                ;are we at the end of digits ?
          jz        DBINTODEC6          ;yes - this is significant ANYWAY
          test      bh,bh               ;has significance been found ?
          jnz       DBINTODEC6          ;yes - no zero-suppression
          test      bl,bl               ;is the digit a leading zero ?
          jz        DBINTODEC8          ;yes - finished this iteration
          mov       bh,1                ;indicate significance started
DBINTODEC6:
          add       bl,'0'              ;make it printable
          mov       al,bl               ;set it for storing to output
          stosb
          cmp       cl,4                ;are we at a comma-break ?
          jz        DBINTODEC7
          cmp       cl,7
          jz        DBINTODEC7
          cmp       cl,10
          jnz       DBINTODEC8
DBINTODEC7:
          mov       al,','              ;insert a comma character
          stosb
DBINTODEC8:
          pop       dx                  ;restore residue
          pop       ax                  
          add       si,4                ;move down table
          loop      DBINTODEC1          ;keep going for all digits
          pop       di
          pop       si
          pop       bx
          pop       ax
          pop       dx                  ;retrieve registers
          ret

DBINTODECTABLE:
          dd        1000000000
          dd        100000000
          dd        10000000
          dd        1000000
          dd        100000
          dd        10000
          dd        1000
          dd        100
          dd        10
          dd        1

;**************************************************************************
;** initscreen - CLS, Copyright, etc...
initscreen:
          push      ax
          push      dx
          
          mov       ah,0fh              ; Clear Screen
          int       10h
          mov       ah,00h
          int       10h

          lea       dx,titles           ; Program title
          call      printstring

          lea       dx,dash_div         ; Dashes divide line
          call      printstring

          lea       dx,connect          ; Connect '85         
          call      printstring

          lea       dx,data             ; Wait for return...
          mov       ah,0ah
          int       21h

          pop       dx
          pop       ax
          ret

;**************************************************************************
;** Now then...lets get the info

; vars req'd:
sum       dw        0                   ; Checksum
vcount    db        0                   ; Count of received variables
cmd       db        0                   ; Last command received
dofs      dw        0                   ; Variable offset in array
didx      dw        0                   ; Pointer to next free location
pktsize   dw        0                   ; Packet size
szebuf    db        '$$$$$$$$'          ; Buffer for bin -> dec conversion

readthecalc:
          push      ax
          push      bx
          push      cx
          push      dx
          push      di
          lea       dx,pause
          call      printstring

mainloop: call      putstar
waitloop: call      receive             ; Returns TI byte in AH
          cmp       ah,85h
          jne       waitloop
          call      receive          
          cmp       ah,56h              ; Packet okay. Skip next two bytes.
          jne       rtc1
          call      receive
          call      receive

rtc1:     cmp       ah,6                ; C6 = Variable header
          je        rtc2
          cmp       ah,15h              ; C15 = Variable data
          je        rtc2
          jmp       endloop             ; Neither. Goto end of loop

rtc2:     mov       [cmd],ah            ; Store command
          cmp       ah,6                ; If new variable...
          jne       rtc3
          lea       dx,fetch            ; ...Show 'Recieving!' message...
          call      putstring
          inc       [vcount]            ; ...and increment vcount.
rtc3:     mov       [sum],0             ; Reset checksum
          call      receive             ; Get next byte (size of packet)
          mov       bl,ah               ; BX=size of packet
          call      receive
          mov       bh,ah
          mov       [pktsize],bx        ; Store size
          lea       di,data             ; Put size in data array
          add       di,[dofs]
          add       di,[didx]
          mov       [di],bl
          inc       di
          mov       [di],bh
          inc       [didx]              ; Adjust didx
          inc       [didx]

rtc4:     mov       ax,[dofs]           ; Find free place in array
          add       ax,[didx]          
          mov       [w_tmp],ax          ; and store
          
          add       bx,[w_tmp]          ; Maximum value for loop
          mov       cx,[w_tmp]          ; 'Get the packet' loop...
rtc5:     call      receive             ; Get byte
          lea       di,data             ; DX=Start of data array
          add       di,cx               ; Adjust DX to free location
          mov       [di],ah             ; Save byte
          push      ax
          push      bx                  ; Update checksum
          mov       al,ah
          mov       ah,0
          mov       bx,[sum]
          add       bx,ax
          mov       [sum],bx
          pop       bx
          pop       ax
          inc       cx                  ; CX=BX ?
          cmp       bx,cx
          jne       rtc5                ; No - loop back

          call      receive             ; Get checksum
          mov       bl,ah
          call      receive
          mov       bh,ah

          and       [sum],0FFFFh        ; And summed sum with 65535
          cmp       [sum],bx            ; Are they the same ?
          je        rtc6                ; Yep, jump ahead
          mov       ah,05h              ; Nope :( tell calc with a 
          call      send                ; 4-byte sequence:
          mov       ah,5Ah              ;          05,5A,00,00
          call      send
          mov       ah,0
          call      send
          call      send
          jmp       rtc4                ; Refetch packet

rtc6:     mov       dx,[dofs]           ; Adjust dofs for next variable
          add       dx,[didx]
          add       dx,[pktsize]
          mov       [dofs],dx
          mov       [didx],0            ; Reset didx ready for next variable
          mov       ah,05h              ; Tell calculator packet
          call      send                ; received okay :)
          mov       ah,56h
          call      send
          mov       ah,00h
          call      send
          call      send

          cmp       [cmd],06h           ; If the command got the header...
          jne       endloop
          
          mov       ah,05h              ; Tell calculator we want the 
          call      send                ; next packet...
          mov       ah,09h
          call      send
          mov       ah,00h
          call      send
          call      send

endloop:  cmp       ah,92h              ; End of transmission.
          je        okaythen
          jmp       mainloop

okaythen: call      receive             ; Get the two last bytes from the
          call      receive             ; calculator

          mov       ah,05h              ; Tell calc, received okay
          call      send
          mov       ah,56h
          call      send
          mov       ah,00h
          call      send
          call      send

          call      initport            ; Reinitialize the port

          lea       dx,finish           ; Say that receive is over
          call      printstring
          lea       dx,stats1           ; Show amount of recieved variables
          call      putstring
          lea       di,szebuf           ; Do bin -> dec conversion
          mov       dx,0
          mov       ax,0
          mov       al,[vcount]
          call      dbintodec
          lea       dx,szebuf           ; Show decimal value
          call      putstring
          lea       dx,stats2
          call      printstring        
          lea       dx,dash_div        ; A line of dashes
          call      printstring

          pop       di
          pop       dx
          pop       cx
          pop       bx
          pop       ax
          ret

;**************************************************************************
;** WriteData - Save to disk!
writedata:
          push      ax
          push      bx
          push      cx
          push      dx
          push      si
          push      di
          mov       ax,0
          cmp       [vcount],1          ; Was more than one var received ?
          je        wd1                 ; Nope...jump to next bit
          mov       [suff],'G'          ; Yep, create a .85G file
          jmp       wd2
wd1:      lea       di,codes            ; Nope...point to codes
          lea       si,data             ; Get data type
          add       si,4h
          mov       al,[si]
          add       di,ax               ; point di to data type
          mov       ah,[di]             ; get the suffix
          mov       [suff],ah
wd2:      mov       ah,3ch              ; Create the TI.85? file
          xor       cx,cx
          lea       dx,fname
          int       21h
          jc        wderr
          mov       [handle],ax         ; Store handle
          mov       ax,[dofs]           ; Store datasize
          mov       [datasize],ax
          mov       ah,40h              ; Write header
          mov       bx,[handle]
          mov       cx,[head_len]
          lea       dx,f_head
          int       21h
          jc        wderr
          mov       ah,40h              ; Write data
          mov       bx,[handle]
          mov       cx,[dofs]
          lea       dx,data
          int       21h
          jc        wderr
          
          xor       ax,ax               ; Do checksum
          mov       bx,0
          mov       cx,[dofs]
          lea       di,data
wd3:      mov       bl,[di]
          add       ax,bx
          inc       di
          loop      wd3

          mov       [w_tmp],ax          ; Write checksum
          mov       ah,40h
          mov       bx,[handle]
          mov       cx,2
          lea       dx,w_tmp
          int       21h
          jc        wderr
          
          mov       ah,3eh              ; Close file
          mov       bx,[handle]
          int       21h
          jc        wderr
          
wdend:    pop       di
          pop       si
          pop       dx
          pop       cx
          pop       bx
          pop       ax
          
          ret

wderr:    lea       dx,err_mess         ; Error handler
          call      printstring
          
          jmp       wdend

;**************************************************************************
;** The main bit :-)
init:     push      ds                  ; get com port address
          pop       bx
          mov       ax,0
          push      ax
          pop       ds
          mov       ax,[ds:0400h]       ; change to 0402 for com2 - this will
          push      bx                  ; be patched with a seperate program
          pop       ds                  ; if com2 req'd
          mov       [portaddr],ax

          call      initport            ; Initialize the com port
          call      initscreen          ; Show the initial screen
          call      readthecalc         ; Get data from calculator
          call      writedata           ; Write data to disk
          
          int       20h                 ; STOP!

; The data array
data      db~24 SEGMENT or ENDS Required~
        0dh,0ah,0ah
          db        'This is not wasted space - it is part of the data',0dh,0ah
          db        'array - may as well fill it up with something',0dh,0ah
          db        'else other than repeated DATA as it is afterwards :)'
          db        0dh,0ah,0ah,'*** Harvester of Sorrow ***',0dh,0ah
          db        'First verse and chorus only...',0dh,0ah
          db        0dh,0ah,0ah
          db        'My life suffocates',0dh,0ah
          db        'Planting seeds of hate',0dh,0ah
          db        'I',27h,'ve loved - turned to hate',0dh,0ah
          db        'Trapped far beyond my fate',0dh,0ah
          db        'I give - you take',0dh,0ah
          db        'This life that I forsake',0dh,0ah
          db        'Been cheated of my youth',0dh,0ah
          db        'You turned this lie to truth',0dh,0ah
          db        0dh,0ah
          db        'Anger, misery',0dh,0ah
          db        'You',27h,'ll suffer unto me',0dh,0ah
          db        0dh,0ah
          db        'Harvester of sorrow',0dh,0ah
          db        'Language of the mad',0dh,0ah
          db        'Harvester of sorrow',0dh,0ah
          db        0dh,0ah
          db        '**************************'
          db        0dh,0ah,0ah
          db        '----------------',0dh,0ah,0ah
          db        0dh,0ah,0ah          

          db        8000 dup('DATA')

cseg      ends
          end       start

