IDEAL
MODEL SMALL, PASCAL
STACK 100h
LOCALS __
P386

include "common.inc"

;*********************
;*****    Data   *****
;*********************
DATASEG
LABEL uninit_start

LABEL font_start
include "font.inc"
LABEL font_end

;overlay other data on top of font
;all of this data gets initialized to zero _after_
;the font is loaded, so it all must be ? initialized here
ORG uninit_start
map              Tile   MAP_WIDTH*MAP_HEIGHT dup(<?>)

LABEL entities_start
player_entity    Entity  <?>
other_entities   Entity  NUM_ENTITIES dup(<?>)
LABEL entities_end

LABEL uninit_end

;move location pointer to end of font if uninit_data was
;less than the size of the font
IF uninit_end LT font_end
ORG font_end
ENDIF

;any initialized data must go here
LABEL palette_start
include "palette.inc"
LABEL palette_end


;*********************
;*****    Code   *****
;*********************
CODESEG
PROC main
                        ;set up data segment
                        mov     ax,@data
                        mov     ds,ax
                        mov     es,ax
                        ;set font and initialize data
                        call    screen_set_font
                        mov     di,offset uninit_start
                        mov     cx,offset uninit_end - offset uninit_start
                        mov     al,0
                        rep     stosb
                        ;set palette
                        mov     dx,003C6h
                        mov     al,0ffh
                        out     dx,al
                        ;initialize palette to white
                        mov     dx,003C8h
                        mov     al,0
                        out     dx,al
                        mov     dx,003C9h
                        mov     al,255
                        mov     cx,256*3
__3:                    out     dx,al
                        loop    __3
                        ;set db16 palette
                        mov     cx,16
                        mov     si,offset palette_start
__5:                    lodsb
                        mov     dx,003C8h
                        out     dx,al
                        mov     dx,003C9h
                        REPT    3
                        lodsb
                        shr     al,2
                        out     dx,al
                        ENDM
                        loop    __5
                        ;disable blink
                        mov     dx,VGA_INPUT_STATUS_0
                        in      al,dx
                        mov     dx,VGA_ATC_REGISTER
                        mov     al,VGA_ATC_MODE
                        out     dx,al
                        mov     al,0
                        out     dx,al
                        ;hide cursor
                        mov     ah,002h
                        mov     bh,0
                        mov     dx,0FFFFh
                        int     10h
                        ;create player
                        mov     [player_entity.char.char],'@'
                        mov     [player_entity.char.attributes],00fh
                        mov     [player_entity.x],10
                        mov     [player_entity.y],3
                        ;create walls
                        mov     di,offset map
                        mov     cx,0
__10:                   mov     [(Tile ptr di).char.char],219
                        mov     [(Tile ptr di).char.attributes],cl
                        mov     [(Tile ptr di).flags],1 SHL TFLAGS_SOLID
                        add     di,size Tile
                        inc     cx
                        cmp     cx,16
                        jne     __10
__loop:                 call    screen_clear
                        call    map_draw
                        call    entity_draw_all
                        ;wait for key
                        xor     ax,ax
                        int     16h
                        cmp     ah,SCAN_ESCAPE
                        je      __exit
                        call    entity_move_player
                        jmp     __loop
__exit:                 ;reset font
                        mov     ax,01101h
                        mov     bl,0
                        int     10h
                        ;clear screen
                        mov     ax,00003h
                        int     10h
                        ;exit
                        mov     ax,04C00h
                        int     21h
ENDP main




END main