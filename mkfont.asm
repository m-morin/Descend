;Create a font from a tga file.
;This program assumes the rga file is a data type 1 (indexed)
;tga of size 128x224. Only the least significant bit of the
;color index of each pixel is used.
IDEAL
MODEL SMALL, PASCAL
STACK 100h
LOCALS __
P386

DATASEG
db_str                  db      "db $"
com_str                 db      ", $"
nl_str                  db      13,10,'$'
num                     db      "0??h$"
scratch                 db      32 dup(?)
image_data_offset       dw      0
bytes_written           dw      0

TGA_WIDTH               equ     128
TGA_HEIGHT              equ     224

FONT_WIDTH              equ     8
FONT_HEIGHT             equ     14
FONT_CHARS_PER_ROW      equ     16

TGA_ID_FIELD_LENGTH     equ     0
TGA_COLOR_MAP_LENGTH    equ     5
TGA_COLOR_MAP_ENT_SIZE  equ     7
TGA_ID_FIELD            equ     18


CODESEG
PROC main
                        ;terminate tail
                        xor     bx,bx
                        mov     bl,[byte ptr 80h]
                        mov     [byte ptr 81h+bx],'$'
                        ;open file
                        mov     dx,082h
                        mov     ax,03D00h
                        int     21h
                        jc      __exit
                        mov     bx,ax
                        ;set up segment registers
                        mov     ax,@data
                        mov     ds,ax
                        mov     es,ax
                        ;read header into scratch
                        mov     ax,03F00h
                        mov     cx,18
                        mov     dx,offset scratch
                        int     21h
                        jc      __close
                        ;calculate offset to image data
                        mov     ax,[word ptr scratch + TGA_COLOR_MAP_LENGTH]
                        mov     cx,[word ptr scratch + TGA_COLOR_MAP_ENT_SIZE]
                        shr     cx,3
                        mul     cx
                        movzx   cx,[byte ptr scratch + TGA_ID_FIELD_LENGTH]
                        add     ax,cx
                        add     ax,TGA_ID_FIELD
                        mov     [word ptr image_data_offset],ax
                        ;output all characters
                        xor     al,al
__loop:                 push    ax
                        call    write_char
                        pop     ax
                        inc     al
                        cmp     al,0
                        jne     __loop
__close:                mov     ah,03Eh
                        int     21h
__exit:                 mov     ax,04C00h
                        int     21h
ENDP main


;***** write_char *****
;Write character from TGA to output
;Parameters: al=char
PROC write_char
USES ax,cx,dx
                        ;calculate offset of character
                        movzx   cx,al
                        xor     dx,dx
                        ;cx=y*1792, FONT_WIDTH * FONT_CHARS_PER_ROW * FONT_HEIGHT
                        shr     cx,4
                        shl     cx,8
                        add     dx,cx
                        shl     cx,1
                        add     dx,cx
                        shl     cx,1
                        add     dx,cx
                        ;cx+=x*FONT_WIDTH+image_data_offset
                        movzx   cx,al
                        and     cx,00Fh
                        shl     cx,3
                        add     dx,cx
                        add     dx,[word ptr image_data_offset]
                        ;seek to beginning of char in image data
                        mov     ax,04200h
                        xor     cx,cx
                        int     21h
                        ;write FONT_HEIGHT rows of pixels
                        mov     cx,FONT_HEIGHT
__10:                   call    read_and_pack_byte
                        call    write_byte
                        ;seek forward to next row in char
                        push    cx
                        mov     dx,FONT_WIDTH*FONT_CHARS_PER_ROW-FONT_WIDTH
                        xor     cx,cx
                        mov     ax,04201h
                        int     21h
                        pop     cx
                        loop    __10
                        ret
ENDP write_char


;***** write_byte *****
;Write db directive for byte
;Parameters: al=byte
PROC write_byte
USES ax,dx,ax
                        ;convert byte to ASCII
                        ;high nibble
                        mov     ah,0
                        shl     ax,4
                        add     ah,'0'
                        cmp     ah,'9'
                        jle     __10
                        add     ah,'A'-'9'-1
__10:                   mov     [byte ptr num+1],ah
                        ;low nibble
                        shr     al,4
                        add     al,'0'
                        cmp     al,'9'
                        jle     __20
                        add     al,'A'-'9'-1
__20:                   mov     [byte ptr num+2],al
                        mov     ah,009h
                        ;first byte on line?
                        test    [byte ptr bytes_written],007h
                        jnz     __30
                        ;output line prefix
                        mov     dx,offset db_str
                        int     21h
__30:                   ;output byte
                        mov     dx,offset num
                        int     21h
                        inc     [word ptr bytes_written]
                        ;output newline or comma
                        test    [byte ptr bytes_written],007h
                        mov     dx,offset com_str
                        jnz     __40
                        mov     dx,offset nl_str
__40:                   int     21h
                        ret
ENDP write_byte


;***** read_byte *****
;Read byte from file descriptor
;Parameters: bx=fd
;Returns: cf=error, al=byte
;Mangles: ah
PROC read_byte
USES cx,dx
                        mov     ax,03F00h
                        mov     cx,1
                        mov     dx,offset scratch
                        int     21h
                        mov     al,[byte ptr scratch]
                        ret
ENDP read_byte


;***** read_and_pack_byte *****
;Read 8 bytes from file descriptor and pack into 1 byte
;Parameters: bx=fd
;Returns: cf=error, al=byte
;Mangles: ah
PROC read_and_pack_byte
USES cx,dx,si
                        ;read 8 bytes
                        mov     ax,03F00h
                        mov     cx,8
                        mov     dx,offset scratch
                        int     21h
                        ;shift LSB of each into ah
                        xor     ah,ah
                        mov     si,offset scratch
__1:                    lodsb
                        rcr     al,1
                        rcl     ah,1
                        loop    __1
                        mov     al,ah
                        ret
ENDP read_and_pack_byte


END main