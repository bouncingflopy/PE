.386
IDEAL
MODEL small
STACK 100h
DATASEG

; -------------------------------------------------------------------------------------
; -------------------------------- DATA MANAGEMENT ------------------------------------
; -------------------------------------------------------------------------------------
; the dots array is sorted in the following order: x position, y position, color
dot_amount dw 0
dots dw 100h dup (?, ?, ?), 321
dots_prev dw 100h dup (?, ?, ?), 321
dots_wall_prev dw 100h dup (?, ?, ?), 321
real dw 100h dup (?, ?, ?), 321

; the sticks array is sorted in the following order: first dot, second dot, color
stick_amount dw 0
sticks dw 100h dup (?, ?, ?), 0
sticks_length dw 100h dup (?, ?, ?), 0

; mode: 0 -> sandbox simulation setup, 1 -> run simulation
mode dw 0
stick_handle dw 0
selected dw 0
saved_color dw 0
left dw 1
left_prev dw 1
right dw 0
right_prev dw 0
fpu dd ?
default_palette db 256*4 dup (0)

; button handling
button_not_pressed dw 0EBh
button_pressed dw 052h
button_nuclear_state dw 0
button_big_state dw 0
button_inverse_state dw 0
button_multi_state dw 0
button_color1_state dw 1
button_color2_state dw 0
button_color3_state dw 0

; button selected center, button selected size
button_nuclear dw 18, 55, 9
button_big dw 18, 85, 9
button_inverse dw 18, 115, 9
button_multi dw 18, 145, 9
button_color1 dw 206, 81, 4
button_color2 dw 206, 108, 4
button_color3 dw 206, 134, 4

; colors
dot_color dw 12
selected_color dw 29
locked_color dw 79
stick_color dw 231
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

; -------------------------------------------------------------------------------------
; --------------------------------- FILE SETTINGS -------------------------------------
; -------------------------------------------------------------------------------------
; bmp display
current_file dw 0
file_header db 54 dup (0)
file_palette db 256*4 dup (0)
file_line db 320 dup (0)

; bmp file names
file_title db 'pe_title.bmp', 0
file_how1 db 'pe_how1.bmp', 0
file_how2 db 'pe_how2.bmp', 0
file_settings db 'pe_opt.bmp', 0
file_end db 'pe_end.bmp', 0

; button borders
; x1, y1, x2, y2
title_start dw 112, 64, 206, 97
title_how dw 57, 102, 262, 134
title_exit dw 110, 141, 208, 169
how2_menu dw 85, 173, 233, 196
settings_exit dw 5, 179, 57, 194
settings_start dw 263, 177, 313, 194
settings_nuclear dw 6, 42, 30, 66
settings_big dw 6, 72, 30, 96
settings_inverse dw 6, 102, 30, 126
settings_multi dw 6, 132, 30, 156
settings_color1 dw 199, 73, 213, 87
settings_color2 dw 199, 100, 213, 114
settings_color3 dw 199, 126, 213, 140
end_menu dw 85, 150, 233, 173
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

; -------------------------------------------------------------------------------------
; ----------------------------- COSTUMIZABLE SETTINGS ---------------------------------
; -------------------------------------------------------------------------------------
; settings
nuclear dw 0
gravity dw 1
dot_size dw 1
search_sens dw 2

; colors
current_color dw 1
color_1 dw 9, 43, 98, 6
color_2 dw 49, 53, 34, 41
color_3 dw 12, 29, 79, 231
; dot color, selected color, locked color, stick color
; -------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------------

CODESEG

; open a bmp
; input: file name in memory
; output: file handle
proc bmp_open
	push bp
	mov bp, sp
	push ax dx
	
	; open file
	mov ax, 3D00h
	mov dx, [bp+4]
	int 21h
	
	; file handle
	mov [bp+4], ax
	
	pop dx ax bp
	ret
endp bmp_open

; read bmp header
; input: file handle, file header in memory
; output: file handle
proc bmp_header
	push bp
	mov bp, sp
	push ax bx cx dx
	
	; read header
	mov ax, 3f00h
	mov bx, [bp+6]
	mov cx, 54
	mov dx, [bp+4]
	int 21h
	
	pop dx cx bx ax bp
	ret 2
endp bmp_header

; read bmp palette
; input: file handle, file palette in memory
; output: file handle
proc bmp_palette
	push bp
	mov bp, sp
	push ax bx cx dx
	
	; read palette
	mov ax, 3f00h
	mov bx, [bp+6]
	mov cx, 400h
	mov dx, [bp+4]
	int 21h
	
	pop dx cx bx ax bp
	ret 2
endp bmp_palette

; display palette from memory
; input: file palette in memory
; output: none
proc palette
	push bp
	mov bp, sp
	push ax cx dx si
	
	mov si, [bp+4]
	mov cx, 256
	
	; copy starting index
	mov dx, 3C8h
	mov al, 0
	out dx, al
	
	; copy palette
	inc dx
	palette_loop:
		; red
		mov al, [si+2]
		shr al, 2
		out dx, al
		
		; green
		mov al, [si+1]
		shr al, 2
		out dx, al
		
		; blue
		mov al, [si]
		shr al, 2
		out dx, al
		
		add si, 4
	loop palette_loop
	
	; insert last color
	mov dx, 3C8h
	mov al, 0fh
	out dx, al
	inc dx
	mov al, 63
	out dx, al
	out dx, al
	out dx, al
	
	; change mouse color
	
	
	pop si dx cx ax bp
	ret 2
endp palette

; read computer's default palette
; input: palette storage in memory
; output: none
proc read_palette
	push bp
	mov bp, sp
	push ax cx dx si
	
	mov si, [bp+4]
	mov cx, 256
	
	; copy starting index
	mov dx, 3C7h
	mov al, 0
	out dx, al
	
	; copy palette
	inc dx
	inc dx
	read_palette_loop:
		; red
		in al, dx
		shl al, 2
		mov [si+2], al
		
		; green
		in al, dx
		shl al, 2
		mov [si+1], al
		
		; blue
		in al, dx
		shl al, 2
		mov [si], al
		
		add si, 4
	loop read_palette_loop
	
	pop si dx cx ax bp
	ret 2
endp read_palette

; display bitmap from bmp
; input: file handle, file line in memory
; output: file handle
proc bmp_bitmap
	push bp
	mov bp, sp
	push ax cx dx di si
	
	mov cx, 200
	bitmap_loop:
		push cx
		
		; di = cx*320
		mov di,cx
		shl cx, 6
		shl di, 8
		add di, cx
		
		; read line
		mov ax, 3f00h
		mov cx, 320
		mov bx, [bp+6]
		mov dx, [bp+4]
		int 21h
		
		; copy line to screen
		cld
		mov cx, 320
		mov si, [bp+4]
		rep movsb
		
		pop cx
	loop bitmap_loop
	
	pop si di dx cx ax bp
	ret 2
endp bmp_bitmap

; close opened bmp file
; input: file handle
; output: none
proc bmp_close
	push bp
	mov bp, sp
	push ax bx
	
	; close file
	mov ax, 3e00h
	mov bx, [bp+4]
	int 21h
	
	pop bx ax bp
	ret 2
endp bmp_close

; display a bmp file
; input: file name in memory, file header in memory, file palette in memory, file line in memory
; output: none
proc display_bmp
	push bp
	mov bp, sp
	
	push [word ptr bp+10]
	call bmp_open
	push [word ptr bp+8]
	call bmp_header
	push [word ptr bp+6]
	call bmp_palette
	push [word ptr bp+6]
	call palette
	push [word ptr bp+4]
	call bmp_bitmap
	call bmp_close
	
	pop bp
	ret 8
endp display_bmp

; delay
; input: none
; output: none
proc delay
	push cx
	
	mov cx, 50
	outer_loop:
		push cx
		
		mov cx, 0FFFFh
		inner_loop:
		loop inner_loop
		
		pop cx
	loop outer_loop
	
	pop cx
	ret
endp delay

; delay
; input: none
; output: none
proc delay_physics
	push cx
	
	mov cx, 40
	outer_loop_physics:
		push cx
		
		mov cx, 0FFFFh
		inner_loop_p:
		loop inner_loop_p
		
		pop cx
	loop outer_loop_physics
	
	pop cx
	ret
endp delay_physics

; draw a pixel to the screen
; input: x position, y position, color
; output: none
proc draw_dot
	push bp
	mov bp, sp
	push ax cx dx di
	
	; get screen position - y*320+x
	mov ax, [bp+6]
	mov cx, 320
	xor dx, dx
	mul cx
	add ax, [bp+8]
	mov di, ax
	
	; get color and display color
	mov ax, [bp+4]
	cmp [byte ptr es:di], al
	je draw_dot_skip
	mov [es:di], al
	
	draw_dot_skip:
	pop di dx cx ax bp
	ret 6
endp draw_dot

; access an array in memory by index
; input: array start location, element in array
; output: beginning of element data in array
proc array_access
	push bp
	mov bp, sp
	push ax cx
	
	; get starting position of element information in array
	mov ax, [bp+4]
	dec ax
	mov cx, 6
	mul cl
	add ax, [bp+6]
	mov [bp+6], ax
	
	pop cx ax bp
	ret 2
endp array_access

; reset unselected buttons' color in settings screen
; input: first button state in memory, first button data in memory, second button state in memory, second button data in memory, button no pressed color in memory
; output: none
proc button_color_reset
	push bp
	mov bp, sp
	push bx
	
	mov bx, [bp+12]
	mov [word ptr bx], 0
	mov bx, [bp+10]
	push bx
	mov bx, [bp+4]
	push [word ptr bx]
	call display_square_button
	
	mov bx, [bp+8]
	mov [word ptr bx], 0
	mov bx, [bp+6]
	push bx
	mov bx, [bp+4]
	push [word ptr bx]
	call display_square_button
	
	pop bx bp
	ret 10
endp button_color_reset

; select and deselect a button in settings screen
; input: button data in memory, color
; output: none
proc display_square_button
	push bp
	mov bp, sp
	push ax bx cx dx si
	
	; hide mouse
	mov ax, 2
	int 33h
	
	; get data
	mov bx, [bp+6]
	
	; find top-left corner
	mov ax, [bx]
	mov dx, [bx+2]
	sub ax, [bx+4]
	sub dx, [bx+4]
	
	mov si, [bp+4]
	mov cx, [bx+4]
	shl cx, 1
	inc cx
	button_column:
		push ax cx
		
		mov cx, [bx+4]
		shl cx, 1
		inc cx
		button_row:
			push ax dx si
			call draw_dot
			
			inc ax
		loop button_row
		
		pop cx ax
	inc dx
	loop button_column
	
	; show mouse
	mov ax, 1
	int 33h
	
	pop si dx cx bx ax bp
	ret 4
endp display_square_button

; display a square
; input: blackout, dots start, dot position in array, size of square
; output: none
proc display_square
	push bp
	mov bp, sp
	push ax bx cx dx di
	
	push [word ptr bp+8] [word ptr bp+6]
	call array_access
	pop bx
	
	; check if dot isnt too close to border
		mov ax, [bx]
		cmp ax, [bp+4]
		jl cant_display
		mov cx, 320
		sub cx, [bp+4]
		cmp ax, cx
		jg cant_display
		
		mov dx, [bx+2]
		cmp dx, [bp+4]
		mov cx, 320
		sub cx, [bp+4]
		cmp dx, cx
		jg cant_display
	
	; find top-left corner
	sub ax, [bp+4]
	sub dx, [bp+4]
	
	mov cx, [bp+10]
	cmp cx, 0
	je square_skip_color_read
	mov cx, [bx+4]
	square_skip_color_read:
	mov bx, cx
	
	mov cx, [bp+4]
	shl cx, 1
	inc cx
	column:
		push ax cx
		
		mov cx, [bp+4]
		shl cx, 1
		inc cx
		row:
			push ax dx bx
			call draw_dot
			
			inc ax
		loop row
		
		pop cx ax
	inc dx
	loop column
	
	cant_display:
	pop di dx cx bx ax bp
	ret 8
endp display_square

; the naive line drawing algorithm
; input: dx, dy, y or x mode, x1, y1, x2, y2, color
; outupt: none
proc naive_algo
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	; get xy mode
	mov bx, [bp+14]
	
	; dx = x1 − x2
		mov di, [bp+18]
	
	; dy = y1 − y2
		mov si, [bp+16]
	
	; for x from x1 to x2 do
	mov cx, [bp+12]
	dec cx
	naive_algo_loop:
		inc cx
		
		; y = yLow + dy × (x − xLow) / dx
		mov ax, cx
		sub ax, [bp+12]
		
		xor dx, dx
		mul si
		div di
		
		; compare y's
			mov dx, [bp+10]
			cmp dx, [bp+6]
			jb naive_y_normal
			
			mov dx, [bp+10]
			sub dx, ax
			mov ax, dx
			jmp after_naive_y
			
			naive_y_normal:
			add ax, [bp+10]
			after_naive_y:
			
		; plot(x, y)
			cmp bx, 0
			jne yx
				push cx
				push ax
			jmp after_mode
			
			yx:
				push ax
				push cx
			
			after_mode:
			push [word ptr bp+4]
			call draw_dot
			
		cmp cx, [bp+8]
		jne naive_algo_loop
	
	pop si di dx cx bx ax bp
	ret 16
endp naive_algo

; set up the inputs for the naive algorithm
; input: x1, y1, x2, y2, color
; output: none
proc naive_algo_setup
	push bp
	mov bp, sp
	push ax di si
	
	mov ax, [bp+12]
	cmp ax, [bp+8]
	jne not_equal
	mov ax, [bp+10]
	cmp ax, [bp+6]
	jne not_equal
	
	jmp naive_algo_setup_end
	not_equal:
	
	; dx
		mov ax, [bp+12]
		cmp ax, [bp+8]
		jb dx_else
		
		mov di, [bp+12]
		sub di, [bp+8]
		jmp dx_after
		
		dx_else:
		mov di, [bp+8]
		sub di, [bp+12]
		dx_after:
	
	; dy
		mov ax, [bp+10]
		cmp ax, [bp+6]
		jb dy_else
		
		mov si, [bp+10]
		sub si, [bp+6]
		jmp dy_after
		
		dy_else:
		mov si, [bp+6]
		sub si, [bp+10]
		dy_after:
	
	; ------------
	; 12 - Ax
	; 10 - Ay
	; 8 - Bx
	; 6 - By
	; di - Dx
	; si - Dy
	; 4 - color
	; ------------
	
	
	; if di > si:
		; if 12 > 8:
			; 8, 6, 12, 10
		; else:
			; 12, 10, 8, 6
	; else:
		; if 10 > 6
			; 6, 8, 10, 12
		; else:
			; 10, 12, 6, 8
	
	cmp di, si
	jb main_else
		
		push di si
		mov ax, 0
		push ax
		mov ax, [bp+12]
		cmp ax, [bp+8]
		jb main_x_else
		
			push [word ptr bp+8] [word ptr bp+6] [word ptr bp+12] [word ptr bp+10] [word ptr bp+4]
			call naive_algo
		jmp naive_algo_setup_end
		
		main_x_else:
			push [word ptr bp+12] [word ptr bp+10] [word ptr bp+8] [word ptr bp+6] [word ptr bp+4]
			call naive_algo
	jmp naive_algo_setup_end
	
	main_else:
		
		push si di
		mov ax, 1
		push ax
		mov ax, [bp+10]
		cmp ax, [bp+6]
		jb main_y_else
		
			push [word ptr bp+6] [word ptr bp+8] [word ptr bp+10] [word ptr bp+12] [word ptr bp+4]
			call naive_algo
		jmp naive_algo_setup_end
		
		main_y_else:
			push [word ptr bp+10] [word ptr bp+12] [word ptr bp+6] [word ptr bp+8] [word ptr bp+4]
			call naive_algo
	
	naive_algo_setup_end:
	pop si di ax bp
	ret 10
endp naive_algo_setup

; display a line
; input: blackout, sticks start, stick position in array, dots start
; output: none
proc display_stick
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	push [word ptr bp+8]
	push [word ptr bp+6]
	call array_access
	pop bx
	
	; get first dot's x and y positions
	push bx
	mov bx, [bx]
	push [word ptr bp+4] bx
	call array_access
	pop bx
	mov cx, [bx]
	mov dx, [bx+2]
	pop bx
	
	; get second dot's x and y positions
	add bx, 2
	push bx
	mov bx, [bx]
	push [word ptr bp+4] bx
	call array_access
	pop bx
	mov di, [bx]
	mov si, [bx+2]
	pop bx
	
	; get stick color
	mov ax, [bp+10]
	cmp ax, 0
	je stick_skip_color_read
	add bx, 2
	mov ax, [bx]
	stick_skip_color_read:
	
	; ------------
	; cx - Ax
	; dx - Ay
	; di - Bx
	; si - By
	; ax - color
	; ------------
	
	push cx dx di si ax
	call naive_algo_setup
	
	pop si di dx cx bx ax bp
	ret 8
endp display_stick

; append element to the end of an array
; input: new element's first property, new element's second property, new element's color, array start, array amount location in memory
; output: output
proc array_add
	push bp
	mov bp, sp
	push ax bx
	
	mov bx, [bp+4]
	mov ax, [bx]
	inc ax
	mov [bx], ax
	
	push [word ptr bp+6] ax
	call array_access
	pop bx
	
	mov ax, [bp+12]
	mov [bx], ax
	mov ax, [bp+10]
	mov [bx+2], ax
	mov ax, [bp+8]
	mov [bx+4], ax
	
	pop bx ax bp
	ret 10
endp array_add

; check if mouse is over a dot
; input: search sensitivity, dot size, dot array start, x lookup, y lookup
; output: start of element in memory; 0 if no element is selected
proc search_dots_by_position
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	mov si, [bp+10]
	add si, [bp+12]
	
	mov bx, [bp+8]
	sub bx, 6
	search_loop:
	add bx, 6
	
	mov cx, [bp+6]
	sub cx, si
	search_x_loop:
		inc cx
		
		cmp cx, [bx]
		jne search_x_loop_end
			push cx
			
			mov cx, [bp+4]
			sub cx, si
			search_y_loop:
			inc cx
			
			cmp cx, [bx+2]
			jne search_y_loop_end
				
				mov ax, bx
				sub ax, [bp+8]
				add ax, 6
				xor dx, dx
				mov di, 6
				div di
				mov dx, ax
				
				pop cx
				jmp end_search
			
			search_y_loop_end:
			mov dx, [bp+4]
			add dx, si
			cmp cx, dx
			jbe search_y_loop
		
		pop cx
		search_x_loop_end:
		mov dx, [bp+6]
		add dx, si
		cmp cx, dx
		jbe search_x_loop
	
	mov ax, 321
	cmp [bx], ax
	jne search_loop
	
	mov dx, 0
	end_search:
	mov [bp+12], dx
	
	pop si di dx cx bx ax bp
	ret 8
endp search_dots_by_position

; clear the screen
; input: none
; output: none
proc clear
	push ax cx di
	
	mov ax, 0
	
	mov cx, 320*200
	clear_loop:
		mov di, cx
		cmp [byte ptr es:di], al
		je clear_loop_skip
		mov [es:di], al
		clear_loop_skip:
	loop clear_loop
	
	pop di cx ax
	ret
endp clear

; input: dots in memory, prev dots in memory, dot number in array
; output: cahnge or no change
proc check_change_dot
	push bp
	mov bp, sp
	push ax bx cx dx si di
	
	mov cx, 0
	
	push [word ptr bp+8] [word ptr bp+4]
	call array_access
	pop si
	
	push [word ptr bp+6] [word ptr bp+4]
	call array_access
	pop di
	
	mov ax, [si]
	mov dx, [di]
	cmp ax, dx
	jne check_dot_changed
	mov ax, [si+2]
	mov dx, [di+2]
	cmp ax, dx
	jne check_dot_changed
	mov ax, [si+4]
	mov dx, [di+4]
	cmp ax, dx
	jne check_dot_changed
	jmp check_dots_not_changed
	
	check_dot_changed:
	mov cx, 1
	check_dots_not_changed:
	mov [bp+8], cx
	
	pop di si dx cx bx ax bp
	ret 4
endp check_change_dot

; input: dots in memory, prev dots in memory, sticks start in memory, dot number in array
; output: cahnge or no change
proc check_change_stick
	push bp
	mov bp, sp
	push ax bx cx dx si di
	
	mov cx, 0
	
	push [word ptr bp+6] [word ptr bp+4]
	call array_access
	pop bx
	
	push [word ptr bp+10] [word ptr bx]
	call array_access
	pop si
	push [word ptr bp+8] [word ptr bx]
	call array_access
	pop di
	
	mov ax, [si]
	mov dx, [di]
	cmp ax, dx
	jne check_stick_changed
	mov ax, [si+2]
	mov dx, [di+2]
	cmp ax, dx
	jne check_stick_changed
	mov ax, [si+4]
	mov dx, [di+4]
	cmp ax, dx
	jne check_stick_changed
	
	push [word ptr bp+10] [word ptr bx+2]
	call array_access
	pop si
	push [word ptr bp+8] [word ptr bx+2]
	call array_access
	pop di
	
	mov ax, [si]
	mov dx, [di]
	cmp ax, dx
	jne check_stick_changed
	mov ax, [si+2]
	mov dx, [di+2]
	cmp ax, dx
	jne check_stick_changed
	mov ax, [si+4]
	mov dx, [di+4]
	cmp ax, dx
	jne check_stick_changed
	jmp check_stick_not_changed
	
	check_stick_changed:
	mov cx, 1
	check_stick_not_changed:
	mov [bp+10], cx
	
	pop di si dx cx bx ax bp
	ret 6
endp check_change_stick

; input: dots in memory, real in memory, dot amount
; output: none
proc copy_real
	push bp
	mov bp, sp
	push bx cx di
	
	mov cx, [bp+4]
	copy_real_loop:
		push [word ptr bp+8] cx
		call array_access
		pop di
		
		push [word ptr bp+6] cx
		call array_access
		pop bx
		
		push cx
		mov cx, 3
		copy_real_loop_inner:
			mov ax, [di]
			mov [bx], ax
			add di, 2
			add bx, 2
		loop copy_real_loop_inner
		pop cx
	loop copy_real_loop
	
	pop di cx bx bp
	ret 6
endp copy_real

; render the dots and sticks from arrays in memory
; input: real in memory, nuclear mode, wall dots start in memory, prev dots start in memory, dots start in memory, dots amount, dots size, sticks start in memory, stick amount
; ouput: none
proc render
	push bp
	mov bp, sp
	push bx cx di
	
	mov bx, [bp+18]
	cmp bx, 1
	je after_clear
		mov cx, [bp+4]
		clear_render_sticks:
			cmp cx, 0
			je clear_render_sticks_after
			
			push [word ptr bp+14] [word ptr bp+12] [word ptr bp+6] cx
			call check_change_stick
			pop bx
			cmp bx, 0
			je clear_stick_skip
			
			mov bx, 0
			push bx [word ptr bp+6] cx [word ptr bp+20]
			call display_stick
			
			clear_stick_skip:
			
			dec cx
		jmp clear_render_sticks
		clear_render_sticks_after:
		
		mov cx, [bp+10]
		clear_render_dots:
			cmp cx, 0
			je clear_render_dots_after
			
			push [word ptr bp+14] [word ptr bp+12] cx
			call check_change_dot
			pop bx
			cmp bx, 0
			je clear_dot_skip
			
			mov bx, 0
			push bx [word ptr bp+20] cx [word ptr bp+8]
			call display_square
			
			clear_dot_skip:
			
			dec cx
		jmp clear_render_dots
		clear_render_dots_after:
	after_clear:
	
	
	mov cx, [bp+4]
	render_sticks:
		cmp cx, 0
		je render_sticks_after
		
		mov bx, 1
		push bx [word ptr bp+6] cx [word ptr bp+12]
		call display_stick
		
		dec cx
	jmp render_sticks
	render_sticks_after:
	
	mov cx, [bp+10]
	render_dots:
		cmp cx, 0
		je render_dots_after
		
		mov bx, 1
		push bx [word ptr bp+12] cx [word ptr bp+8]
		call display_square
		
		dec cx
	jmp render_dots
	render_dots_after:
	
	pop di cx bx bp
	ret 18
endp render

; constrain dots to borders
; input: dot size, wall dots start in memory, dots element number in memory, point's x, point's y, point's beforeUpdate x, point's beforeUpdate y, prev point's position in memory
; output: edited point's x, edited point's y, edited point's beforeUpdate x, edited point's beforeUpdate y
proc wall
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	mov ax, [bp+12]
	mov dx, [bp+10]
	mov di, [bp+8]
	mov si, [bp+6]
	mov bx, [bp+4]
	
	; copy to wall prev
		push bx
		push ax
		
		mov bx, [bp+16]
		push bx
		mov bx, [bp+14]
		push bx
		call array_access
		pop bx
		mov ax, [bp+8]
		mov [bx], ax
		mov ax, [bp+6]
		mov [bx+2], ax
		mov [word ptr bx+4], 0
		
		pop ax
		pop bx
	
	wall_x_left:
		mov cx, [bp+18]
		cmp ax, cx
		jge wall_x_right
		
		mov ax, [bp+18]
		mov cx, ax
		sub cx, [bx]
		add di, cx
	wall_x_right:
		mov cx, 320
		sub cx, [bp+18]
		sub cx, 1
		cmp ax, cx
		jbe wall_y_up
		
		mov ax, 320
		sub ax, [bp+18]
		sub ax, 1
		mov cx, ax
		sub cx, [bx]
		add di, cx
	wall_y_up:
		mov cx, [bp+18]
		cmp dx, cx
		jge wall_y_down
		
		mov dx, [bp+18]
		mov cx, dx
		sub cx, [bx+2]
		add si, cx
	wall_y_down:
		mov cx, 200
		sub cx, [bp+18]
		sub cx, 1
		cmp dx, cx
		jbe wall_exit
		
		mov dx, 200
		sub dx, [bp+18]
		sub dx, 1
		mov cx, dx
		sub cx, [bx+2]
		add si, cx
	
	wall_exit:
	mov [bp+18], ax
	mov [bp+16], dx
	mov [bp+14], di
	mov [bp+12], si
	
	pop si di dx cx bx ax bp
	ret 8
endp wall

; calculate next frame positions of all dots
; input: gravity, locked color, dots wall start in memory, dots start in memory, previous dots start in memory, dots amount
; output: none
proc physics_dots
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	mov cx, [bp+4]
	physics_dots_loop:
		push cx
		
		push [word ptr bp+8] cx
		call array_access
		pop bx
		
		mov ax, [bp+12]
		cmp [bx+4], ax
		je physics_dots_loop_end
		push bx
		
		mov ax, [bx]
		mov dx, [bx+2]
		mov di, ax
		mov si, dx
		
		push [word ptr bp+6] cx
		call array_access
		pop bx
		
		; ------------
		; ax - pointX
		; dx - pointY
		; di - startPointX
		; si - startPointY
		; bx - prevPoint in memory
		; ------------
		
		sal ax, 1
		sub ax, [bx]
		sal dx, 1
		sub dx, [bx+2]
		; gravity
		add dx, [bp+14]
		
		push [word ptr bp+16] [word ptr bp+10] cx ax dx di si bx
		call wall
		pop si di dx ax
		
		mov [bx], di
		mov [bx+2], si
		
		pop bx
		mov [bx], ax
		mov [bx+2], dx
		
		physics_dots_loop_end:
		pop cx
	loop physics_dots_loop
	
	pop si di dx cx bx ax bp
	ret 14
endp physics_dots

; multiply a number by itself
; input: 16 bit padding, number (16 bit)
; output: number squared (32 bit)
proc msquare
	push bp
	mov bp, sp
	push ax cx edx
	
	mov cx, [bp+4]
	mov ax, cx
	mul cx
	shl edx, 16
	mov dx, ax
	mov [bp+4], edx
	
	pop edx cx ax bp
	ret
endp msquare

; calculate the square root of a number
; input: fpu in memory, number (32 bit)
; output: square root of number (32 bit)
proc msqrt
	push bp
	mov bp, sp
	push eax	 di
	
	mov eax, [bp+4]
	mov di, [bp+8]
	
	mov [di], eax
	fild [dword ptr di]
	fsqrt
	fstp [dword ptr di]
	
	mov eax, [di]
	mov [bp+6], eax
	
	pop di eax bp
	ret 2
endp msqrt

; calculate the distance between two points
; input: fpu in memory, dx, dy
; output: distance (32 bit)
proc distance
	push bp
	mov bp, sp
	push eax edx di si
	
	xor eax, eax
	xor edx, edx
	
	mov di, [bp+4]
	mov si, [bp+6]
	
	; mov di, di*di
	push di di
	call msquare
	pop eax
	
	; mov si, si*si
	push si si
	call msquare
	pop edx
	
	; mov ax, di+si
	add eax, edx
	
	; mov ax, sqrt ax
	push [word ptr bp+8] eax
	call msqrt
	pop eax
	
	mov [bp+6], eax
	
	pop si di edx eax bp
	ret 2
endp distance

; calculate the starting lengths of all sticks
; input: fpu in memory, sticks start in memory, stick amount, dots start in memory, stick length start in memory
; output: none
proc sticks_length_init
	push bp
	mov bp, sp
	push eax bx cx dx di si
	
	mov cx, [bp+8]
	sticks_length_init_loop:
		cmp cx, 0
		je sticks_length_init_loop_exit
		
		; get both dot's x and y location
			mov bx, [bp+10]
			push bx cx
			call array_access
			pop bx
			mov di, [bx]
			mov si, [bx+2]
			
			mov bx, [bp+6]
			push bx di
			call array_access
			pop di
			
			push bx si
			call array_access
			pop si
		
		; calculate dx and dy
			; dx
			mov ax, [di]
			cmp ax, [si]
			jl sticks_length_init_dx
				sub ax, [si]
				jmp sticks_length_init_dx_after
			sticks_length_init_dx:
				mov ax, [si]
				sub ax, [di]
			sticks_length_init_dx_after:
			
			; dy
			mov dx, [di+2]
			cmp dx, [si+2]
			jl sticks_length_init_dy
				sub dx, [si+2]
				jmp sticks_length_init_dy_after
			sticks_length_init_dy:
				mov dx, [si+2]
				sub dx, [di+2]
			sticks_length_init_dy_after:
		
		push [word ptr bp+12] ax dx
		call distance
		pop eax
		
		push [word ptr bp+4] cx
		call array_access
		pop bx
		mov [bx], eax
	
	dec cx
	jmp sticks_length_init_loop
	
	sticks_length_init_loop_exit:
	pop si di dx cx bx eax bp
	ret 10
endp sticks_length_init

; change a dot's position based on stick length change
; input: dot size, fpu in memory, wall dots start in memory, prev dots array start in memory, dots array start in memory, point A, point B, offset X (32 bit), offset Y (32 bit)
; output: none
proc change
	push bp
	mov bp, sp
	push eax bx edx di si
	
	; final = position
		; get first point location in memory
		push [word ptr bp+16] [word ptr bp+14]
		call array_access
		pop bx
		
		mov di, [bx]
		mov si, [bx+2]
	
	; if final[0] > other[0]:
		; final[0] += offsetX
	; else:
		; final[0] -= offsetX
	; if final[1] > other[1]:
		; final[1] += offsetY
	; else:
		; final[1] -= offsetY
	
	; round offsets
		mov bx, [bp+22]
		
		mov eax, [bp+8]
		mov [bx], eax
		fld [dword ptr bx]
		frndint
		fistp [dword ptr bx]
		mov eax, [bx]
		
		mov edx, [bp+4]
		mov [bx], edx
		fld [dword ptr bx]
		frndint
		fistp [dword ptr bx]
		mov edx, [bx]
	
	; get other point location in memory
	push [word ptr bp+16] [word ptr bp+12]
	call array_access
	pop bx
	
	cmp di, [bx]
	jle change_x_smaller
	add di, ax
	jmp change_x_after
	change_x_smaller:
	sub di, ax
	change_x_after:
	
	cmp si, [bx+2]
	jle change_y_smaller
	add si, dx
	jmp change_y_after
	change_y_smaller:
	sub si, dx
	change_y_after:
	
	
	; wall
		push [word ptr bp+16] [word ptr bp+14]
		call array_access
		pop bx
		
		push [word ptr bp+24] [word ptr bp+20] [word ptr bp+14] di si [word ptr bx] [word ptr bx+2] [word ptr bp+18] [word ptr bp+14]
		call array_access
		call wall
		pop si di dx ax
		
	; return final
		mov [bx], di
		mov [bx+2], si
		
		push [word ptr bp+16] [word ptr bp+14]
		call array_access
		pop bx
		
		mov [bx], ax
		mov [bx+2], dx
	
	pop si di edx bx eax bp
	ret 22
endp change

; calculate next frame positions of all sticks
; input: dot size, locked color, wall dots start in memory, prev dots start in memory, fpu in memory, dots start in memory, stick lengths start in memory, sticks start in memory, sticks amount
; output: none
proc physics_sticks
	push bp
	mov bp, sp
	push eax bx ecx edx di si
	
	mov cx, [bp+4]
	physics_sticks_loop:
		cmp cx, 0
		jne physics_sticks_loop_continue
		jmp physics_sticks_end
		physics_sticks_loop_continue:
		
		push cx
		
		; get both dot's x and y location
			mov bx, [bp+6]
			push bx cx
			call array_access
			pop bx
			mov di, [bx]
			mov si, [bx+2]
			
			mov bx, [bp+10]
			push bx di
			call array_access
			pop di
			
			push bx si
			call array_access
			pop si
		
		; calculate dx and dy
			; dx
			mov ax, [di]
			cmp ax, [si]
			jl physics_sticks_dx
				sub ax, [si]
				jmp physics_sticks_dx_after
			physics_sticks_dx:
				mov ax, [si]
				sub ax, [di]
			physics_sticks_dx_after:
			
			; dy
			mov dx, [di+2]
			cmp dx, [si+2]
			jl physics_sticks_dy
				sub dx, [si+2]
				jmp physics_sticks_dy_after
			physics_sticks_dy:
				mov dx, [si+2]
				sub dx, [di+2]
			physics_sticks_dy_after:
			
			mov di, ax
			mov si, dx
			
		; set bx to fpu in memory
		mov bx, [bp+12]
		
		push bx ax dx
		call distance
		pop eax
		
		; get original stick length
		push [word ptr bp+8] cx
		call array_access
		pop bx
		mov edx, [bx]
		
		; set bx to fpu in memory
		mov bx, [bp+12]
		
		; difference = stick.length - distance
		mov [bx], edx
		fld [dword ptr bx]
		mov [bx], eax
		fld [dword ptr bx]
		fsub
		fstp [dword ptr bx]
		mov edx, [bx]
		cmp edx, 0
		je physics_sticks_dont_change
		
		; percent = difference / distance / 2
		mov [bx], edx
		fld [dword ptr bx]
		mov [bx], eax
		fld [dword ptr bx]
		fdiv
		mov [dword ptr bx], 2
		fild [dword ptr bx]
		fdiv
		fstp [dword ptr bx]
		mov edx, [bx]
		
		push cx
		; offsetX = dx * percent
		xor eax, eax
		mov ax, di
		mov [bx], eax
		fild [dword ptr bx]
		mov [bx], edx
		fld [dword ptr bx]
		fmul
		fstp [dword ptr bx]
		mov ecx, [bx]
		
		; offsetY = dy * percent
		xor eax, eax
		mov ax, si
		mov [bx], eax
		fild [dword ptr bx]
		mov [bx], edx
		fld [dword ptr bx]
		fmul
		fstp [dword ptr bx]
		mov edx, [bx]
		
		mov eax, ecx
		pop cx
		
		; -------------------------------
		; implements locking dots:
			; if not stick.pointA.locked:
				; if stick.pointB.locked:
					; offsetX *= 2
					; offsetY *= 2
				; stick.pointA.position = Change(stick.pointA.position, stick.pointB.position, offsetX, offsetY)
			; else:
				; offsetX *= 2
				; offsetY *= 2
			; if not stick.pointB.locked:
				; stick.pointB.position = Change(stick.pointB.position, stick.pointA.position, offsetX, offsetY)
		; -------------------------------
		
		locking:
		push ax bx
			; get dots in memory
				mov bx, [bp+6]
				push bx cx
				call array_access
				pop bx
				mov di, [bx]
				mov si, [bx+2]
				
				mov bx, [bp+10]
				push bx di
				call array_access
				pop di
				
				push bx si
				call array_access
				pop si
			
			mov ax, [di+4]
			cmp ax, [bp+18]
			je a_locked
			
				mov ax, [si+4]
				cmp ax, [bp+18]
				jne b_not_locked
					mov bx, [bp+12]
					
					mov [bx], eax
					fld [dword ptr bx]
					fld [dword ptr bx]
					fadd 
					fstp [dword ptr bx]
					mov eax, [bx]
					
					mov [bx], edx
					fld [dword ptr bx]
					fld [dword ptr bx]
					fadd 
					fstp [dword ptr bx]
					mov edx, [bx]
				
				b_not_locked:
					; stick.pointA.position = Change(stick.pointA.position, stick.pointB.position, offsetX, offsetY)
					push [word ptr bp+20] [word ptr bp+12] [word ptr bp+16] [word ptr bp+14] [word ptr bp+10]
						mov bx, [bp+6]
						push bx cx
						call array_access
						pop bx
					push [word ptr bx] [word ptr bx+2] eax edx
					call change
					
					jmp b_check
			
			a_locked:
				mov bx, [bp+12]
				
				mov [bx], eax
				fld [dword ptr bx]
				fld [dword ptr bx]
				fadd 
				fstp [dword ptr bx]
				mov eax, [bx]
				
				mov [bx], edx
				fld [dword ptr bx]
				fld [dword ptr bx]
				fadd 
				fstp [dword ptr bx]
				mov edx, [bx]
			
			b_check:
				mov ax, [si+4]
				cmp ax, [bp+18]
				je b_locked
					
					; stick.pointB.position = Change(stick.pointB.position, stick.pointA.position, offsetX, offsetY)
					push [word ptr bp+20] [word ptr bp+12] [word ptr bp+16] [word ptr bp+14] [word ptr bp+10]
						mov bx, [bp+6]
						push bx cx
						call array_access
						pop bx
					push [word ptr bx+2] [word ptr bx] eax edx
					call change
			b_locked:
		pop bx ax
		
		physics_sticks_dont_change:
		pop cx
	
	dec cx
	je physics_sticks_end
	jmp physics_sticks_loop
	
	physics_sticks_end:
	pop si di edx ecx bx eax bp
	ret 18
endp physics_sticks

; calculate next frame positions
; input: dot size, gravity, locked color, stick lengths start in memory, fpu in memory, dots wall start in memory, dots start in memory, previous dots start in memory, dots amount, sticks start in memory, sticks amount
; output: none
proc physics
	push bp
	mov bp, sp
	push cx
	
	push [word ptr bp+24] [word ptr bp+22] [word ptr bp+20] [word ptr bp+14] [word ptr bp+12] [word ptr bp+10] [word ptr bp+8]
	call physics_dots
	
	mov cx, 5
		physics_loop_sticks:
		push [word ptr bp+24] [word ptr bp+20] [word ptr bp+14] [word ptr bp+10] [word ptr bp+16] [word ptr bp+12] [word ptr bp+18] [word ptr bp+6] [word ptr bp+4]
		call physics_sticks
	loop physics_loop_sticks
	
	pop cx bp
	ret 22
endp physics

; check if mouse button's input is valid
; input: button's position in memory, previous button's position in memory, new button
; output: valid click - 1; non-valid click / no click - 0
proc click
	push bp
	mov bp, sp
	push ax bx cx dx
	
	mov bx, [bp+8]
	mov cx, [bx]
	mov bx, [bp+6]
	mov dx, [bx]
	mov [bx], cx
	
	mov bx, [bp+8]
	mov ax, [bp+4]
	mov [bx], ax
	
	mov ax, 0
	
	cmp cx, dx
	je click_end
	mov ax, [bp+4]
	
	click_end:
	mov [bp+8], ax
	pop dx cx bx ax bp
	ret 4
endp click

; copy dots from dot array to prev_dot array
; input: dot amount, dots start in memory, prev dots start in memory
; output: none
proc copy_dots
	push bp
	mov bp, sp
	push bx cx di
	
	mov cx, [bp+8]
	dots_prev_copy:
		push [word ptr bp+6] cx
		call array_access
		pop di
		
		push [word ptr bp+4] cx
		call array_access
		pop bx
		
		push cx
		mov cx, 3
		dots_prev_copy_loop:
			mov ax, [di]
			mov [bx], ax
			add di, 2
			add bx, 2
		loop dots_prev_copy_loop
		pop cx
	loop dots_prev_copy
	
	pop di cx bx bp
	ret 6
endp copy_dots

; select a dot
; input: saved color in memory, dots in memory, selected color in memory, new select, select in memory
; output: none
proc select
	push bp
	mov bp, sp
	push ax bx di
	
	mov bx, [bp+4]
	mov di, [bp+6]
	mov [bx], di
	
	push [word ptr bp+10] di
	call array_access
	pop di
	
	; save color
	mov bx, [bp+12]
	mov ax, [di+4]
	mov [bx], ax
	
	mov bx, [bp+8]
	mov [di+4], bx
	
	
	pop di bx ax bp
	ret 10
endp select

; deselect a dot
; input: dots in memory, saved color, select in memory
; output: none
proc deselect
	push bp
	mov bp, sp
	push bx di
	
	push [word ptr bp+8]
	mov bx, [bp+4]
	push [word ptr bx]
	call array_access
	pop di
	
	mov bx, [bp+6]
	mov [di+4], bx
	
	mov bx, [bp+4]
	mov [word ptr bx], 0
	
	pop di bx bp
	ret 6
endp deselect

; check if button is clicked
; input: mouse x, mouse y, button border in memory
; output: 1 if pressed, 0 if not
proc button
	push bp
	mov bp, sp
	push ax bx cx dx di si
	
	; set default value
	mov cx, 0
	
	; load values
	mov bx, [bp+4]
	mov ax, [bp+8]
	mov dx, [bp+6]
	
	; check x
	mov di, [bx]
	mov si, [bx+4]
	cmp ax, di
	jl button_exit
	cmp ax, si
	jg button_exit
	
	; check y
	mov di, [bx+2]
	mov si, [bx+6]
	cmp dx, di
	jl button_exit
	cmp dx, si
	jg button_exit
	
	mov cx, 1
	
	button_exit:
	mov [bp+8], cx
	
	pop si di dx cx bx ax bp
	ret 4
endp button

; exit the program
; input: none
; output: none
proc escape
	mov ax, 2
	int 10h
	mov ax, 4c00h
	int 21h
	
	ret
endp escape

; input: gravity in memory, ending of reset in memory, beginning of second reset in memory, left in memory, left_prev in memory, current_color in memory
; output: none
proc reset
	push bp
	mov bp, sp
	push bx cx
	
	mov cx, [bp+12]
	reset_first_loop:
		sub cx, 2
		
		mov bx, cx
		cmp [word ptr bx], 321
		je reset_first_loop_skip
		mov [word ptr bx], 0
		reset_first_loop_skip:
		
		cmp cx, 0
	jne reset_first_loop
	
	mov bx, [bp+10]
	mov [dword ptr bx], 0
	add bx, 4
	mov [dword ptr bx], 0
	add bx, 4
	mov [word ptr bx], 1
	add bx, 2
	mov [dword ptr bx], 0
	
	mov cx, 1
	mov bx, [bp+14]
	mov [word ptr bx], cx
	mov bx, [bp+8]
	mov [word ptr bx], cx
	mov bx, [bp+6]
	mov [word ptr bx], cx
	mov bx, [bp+4]
	mov [word ptr bx], cx
	
	pop cx bx bp
	ret 12
endp reset

start:
	mov ax, @data
	mov ds, ax
	
	; setup graphic mode
		mov ax, 0A000h
		mov es, ax
		mov ax, 13h
		int 10h
		call clear
	
	; setup mouse
		mov ax, 0
		int 33h
		mov ax, 1
		int 33h
	
	; save computer palette
		mov bx, offset default_palette
		push bx
		call read_palette
	
	; reset
		reset_main:
		mov bx, offset gravity
		push bx
		mov bx, offset default_palette
		push bx
		mov bx, offset button_nuclear_state
		push bx
		mov bx, offset left
		push bx
		mov bx, offset left_prev
		push bx
		mov bx, offset current_color
		push bx
		call reset
	
	; openning screens
	mov [current_file], offset file_title
	screens:
		; hide mouse
		mov ax, 2
		int 33h
		
		mov bx, offset current_file
		push [word ptr bx]
		mov bx, offset file_header
		push bx
		mov bx, offset file_palette
		push bx
		mov bx, offset file_line
		push bx
		call display_bmp
		
		; show mouse
		mov ax, 1
		int 33h
		
		screens_wait:
			; check for escape
			mov ax, 100h
			int 16h
			jz screen_title
			mov ax, 0
			int 16h
			cmp al, 27
			jne screen_title
				call escape	
			
			screen_title:
			cmp [current_file], offset file_title
			jne screen_how1
				; check mouse
				mov ax, 3
				int 33h
				sar cx, 1
				mov ax, bx
				and ax, 1b
				
				mov bx, offset left
				push bx
				mov bx, offset left_prev
				push bx
				push ax
				call click
				pop bx
				cmp bx, 1
				jne screens_wait
				
				screen_title_start:
					push cx dx
					mov bx, offset title_start
					push bx
					call button
					pop bx
					
					cmp bx, 1
					jne screen_title_how
					mov [current_file], offset file_settings
					jmp settings
				
				screen_title_how:
					push cx dx
					mov bx, offset title_how
					push bx
					call button
					pop bx
					
					cmp bx, 1
					jne screen_title_exit
						mov [current_file], offset file_how1
						jmp screens
				
				screen_title_exit:
					push cx dx
					mov bx, offset title_exit
					push bx
					call button
					pop bx
					
					cmp bx, 1
					jne screens_wait
						call escape
				
			screen_how1:
			cmp [current_file], offset file_how1
			jne screen_how2
				; check for enter
				mov ax, 100h
				int 16h
				jz screens_wait
				mov ax, 0
				int 16h
				cmp al, 13
				jne screens_wait
				
				mov [current_file], offset file_how2
				jmp screens
				
			screen_how2:
			cmp [current_file], offset file_how2
			jne screens_wait
				; check mouse
				mov ax, 3
				int 33h
				sar cx, 1
				mov ax, bx
				and ax, 1b
				cmp ax, 1
				jne screens_wait
				
				push cx dx
				mov bx, offset how2_menu
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne screens_wait
				mov [current_file], offset file_title
				jmp screens

		jmp screens_wait
	
	settings:
		; hide mouse
		mov ax, 2
		int 33h
		
		; display settings screen
		mov bx, offset current_file
		push [word ptr bx]
		mov bx, offset file_header
		push bx
		mov bx, offset file_palette
		push bx
		mov bx, offset file_line
		push bx
		call display_bmp
		
		; select first color palette
		mov [button_color1_state], 1
		mov bx, offset button_color1
		push bx
		push [word ptr button_pressed]
		call display_square_button
		
		; show mouse
		mov ax, 1
		int 33h
		
		settings_wait:
			; check for escape
			mov ax, 100h
			int 16h
			jz settings_mouse
			mov ax, 0
			int 16h
			cmp al, 27
			jne settings_mouse
				call escape
			
			; check mouse
			settings_mouse:
				mov ax, 3
				int 33h
				sar cx, 1
				mov ax, bx
				and ax, 1b
				mov bx, offset left
				push bx
				mov bx, offset left_prev
				push bx ax
				call click
				pop bx
				cmp bx, 1
				jne settings_wait
			
			settings_wait_exit:
				push cx dx
				mov bx, offset settings_exit
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_start
					call escape
			
			settings_wait_start:
				push cx dx
				mov bx, offset settings_start
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_nuclear
					jmp sandbox_setup
			
			settings_wait_nuclear:
				push cx dx
				mov bx, offset settings_nuclear
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_big
					cmp [button_nuclear_state], 1
					je settings_wait_nuclear_on
						mov [button_nuclear_state], 1
						mov bx, offset button_nuclear
						push bx
						push [word ptr button_pressed]
						call display_square_button
					jmp settings_wait
					settings_wait_nuclear_on:
						mov [button_nuclear_state], 0
						mov bx, offset button_nuclear
						push bx
						push [word ptr button_not_pressed]
						call display_square_button
					jmp settings_wait
			
			settings_wait_big:
				push cx dx
				mov bx, offset settings_big
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_inverse
					cmp [button_big_state], 1
					je settings_wait_big_on
						mov [button_big_state], 1
						mov bx, offset button_big
						push bx
						push [word ptr button_pressed]
						call display_square_button
					jmp settings_wait
					settings_wait_big_on:
						mov [button_big_state], 0
						mov bx, offset button_big
						push bx
						push [word ptr button_not_pressed]
						call display_square_button
					jmp settings_wait
			
			settings_wait_inverse:
				push cx dx
				mov bx, offset settings_inverse
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_multi
					cmp [button_inverse_state], 1
					je settings_wait_inverse_on
						mov [button_inverse_state], 1
						mov bx, offset button_inverse
						push bx
						push [word ptr button_pressed]
						call display_square_button
					jmp settings_wait
					settings_wait_inverse_on:
						mov [button_inverse_state], 0
						mov bx, offset button_inverse
						push bx
						push [word ptr button_not_pressed]
						call display_square_button
					jmp settings_wait
			
			settings_wait_multi:
				push cx dx
				mov bx, offset settings_multi
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_color1
					cmp [button_multi_state], 1
					je settings_wait_multi_on
						mov [button_multi_state], 1
						mov bx, offset button_multi
						push bx
						push [word ptr button_pressed]
						call display_square_button
					jmp settings_wait
					settings_wait_multi_on:
						mov [button_multi_state], 0
						mov bx, offset button_multi
						push bx
						push [word ptr button_not_pressed]
						call display_square_button
					jmp settings_wait
			
			settings_wait_color1:
				push cx dx
				mov bx, offset settings_color1
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_color2
					cmp [button_color1_state], 1
					je settings_wait
						; deselect all color buttons
						mov bx, offset button_color2_state
						push bx
						mov bx, offset button_color2
						push bx
						mov bx, offset button_color3_state
						push bx
						mov bx, offset button_color3
						push bx
						mov bx, offset button_not_pressed
						push bx
						call button_color_reset
						
						mov [button_color1_state], 1
						mov bx, offset button_color1
						push bx
						push [word ptr button_pressed]
						call display_square_button
						
						mov [word ptr current_color], 1
					jmp settings_wait
			
			settings_wait_color2:
				push cx dx
				mov bx, offset settings_color2
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait_color3
					cmp [button_color2_state], 1
					je settings_wait
						; deselect all color buttons
						mov bx, offset button_color1_state
						push bx
						mov bx, offset button_color1
						push bx
						mov bx, offset button_color3_state
						push bx
						mov bx, offset button_color3
						push bx
						mov bx, offset button_not_pressed
						push bx
						call button_color_reset
						
						mov [button_color2_state], 1
						mov bx, offset button_color2
						push bx
						push [word ptr button_pressed]
						call display_square_button
						
						mov [word ptr current_color], 2
					jmp settings_wait
			
			settings_wait_color3:
				push cx dx
				mov bx, offset settings_color3
				push bx
				call button
				pop bx
				
				cmp bx, 1
				jne settings_wait
					cmp [button_color3_state], 1
					je settings_wait
						; deselect all color buttons
						mov bx, offset button_color1_state
						push bx
						mov bx, offset button_color1
						push bx
						mov bx, offset button_color2_state
						push bx
						mov bx, offset button_color2
						push bx
						mov bx, offset button_not_pressed
						push bx
						call button_color_reset
						
						mov [button_color3_state], 1
						mov bx, offset button_color3
						push bx
						push [word ptr button_pressed]
						call display_square_button
						
						mov [word ptr current_color], 3
					jmp settings_wait
	
	sandbox_setup:
		; hide mouse
		mov ax, 2
		int 33h
		
		call clear
		
		; show mouse
		mov ax, 1
		int 33h
		
		; restore palette
		mov bx, offset default_palette
		push bx
		call palette
		
		; reset mouse
		mov [word ptr left], 1
		mov [word ptr left_prev], 1
		
		; restore default values which dont get reset in reset
		mov [nuclear], 0
		mov [dot_size], 1
		mov [gravity], 1
		
		; load data from setting screen
			setup_check_nuclear:
			cmp [button_nuclear_state], 1
			jne setup_check_big
				mov [nuclear], 1
			
			setup_check_big:
			cmp [button_big_state], 1
			jne setup_check_inverse
				mov [dot_size], 5
			
			setup_check_inverse:
			cmp [button_inverse_state], 1
			jne setup_check_multi
				mov [gravity], -1
			
			setup_check_multi:
			cmp [button_multi_state], 1
			jne setup_check_colors
				shl [gravity], 3
			
			setup_check_colors:
				mov bx, offset dot_color
				mov di, [current_color]
				dec di
				shl di, 3
				add di, offset color_1
				
				mov cx, 4
				setup_check_colors_loop:
				mov ax, [di]
				mov [bx], ax
				add bx, 2
				add di, 2
				loop setup_check_colors_loop
	
	; sandbox loop
	sandbox:
		; get mouse input
		mov ax, 3
		int 33h
		mov ax, bx
		
		; process mouse input
		mov ah, al
		and ah, 1b
		and al, 10b
		sar cx, 1
		
		; check left mouse button
		sandbox_left:
			mov bx, offset left
			push bx
			mov bx, offset left_prev
			push bx
			xor bx, bx
			mov bl, ah
			push bx
			call click
			pop bx
			cmp bx, 1
			jne sandbox_right
			
			; add dot to dots array
			push cx dx
			push [dot_color]
			mov bx, offset dots
			push bx
			mov bx, offset dot_amount
			push bx
			call array_add
		
		; check right mouse button
		sandbox_right:
			mov bx, offset right
			push bx
			mov bx, offset right_prev
			push bx
			xor bx, bx
			sar al, 1
			mov bl, al
			push bx
			call click
			pop bx
			cmp bx, 1
			jne keyboard
			
			; check if a dot is pressed
			mov bx, offset search_sens
			push [word ptr bx]
			mov bx, offset dot_size
			push [word ptr bx]
			mov bx, offset dots
			push bx cx dx
			call search_dots_by_position
			pop di
			
			; handle search results
			cmp di, 0
			je keyboard
			
			cmp [word ptr selected], 0
			je add_select
			cmp [word ptr stick_handle], 1
			je add_stick
			cmp [selected], di
			je only_deselect
			
			switch_select:
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
				
				mov bx, offset saved_color
				push bx
				mov bx, offset dots
				push bx
				mov bx, offset selected_color
				push [word ptr bx]
				push di
				mov bx, offset selected
				push bx
				call select
			jmp keyboard
			
			only_deselect:
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
			jmp keyboard
			
			add_select:
				mov bx, offset saved_color
				push bx
				mov bx, offset dots
				push bx
				mov bx, offset selected_color
				push [word ptr bx]
				push di
				mov bx, offset selected
				push bx
				call select
			jmp keyboard
			
			add_stick:
				mov [word ptr stick_handle], 0
				
				push [word ptr selected]
				push di
				push [word ptr stick_color]
				mov bx, offset sticks
				push bx
				mov bx, offset stick_amount
				push bx
				call array_add
				
				; deselect
				mov bx, offset dots
				push bx
				mov bx, offset saved_color
				push [word ptr bx]
				mov bx, offset selected
				push bx
				call deselect
			jmp keyboard
		
		; check keyboard input
		keyboard:
			; check if a key is pressed
			mov ax, 100h
			int 16h
			jz sandbox_end
			
			; if a key is pressed, get pressed key
			mov ax, 0
			int 16h
			
			cmp al, 27
			jne sandbox_no_escape
				call escape
			sandbox_no_escape:
			cmp al, 13
			je keyboard_enter
			cmp al, ' '
			je keyboard_space
			cmp al, 8
			je keyboard_backspace
			jmp sandbox_end
			
			keyboard_enter:
				mov [mode], 1
				jmp sandbox_end
			
			keyboard_space:
				cmp [word ptr selected], 0
				je sandbox_end
				xor [word ptr stick_handle], 1
				jmp sandbox_end
			
			keyboard_backspace:
				cmp [word ptr selected], 0
				je sandbox_end
				
				mov di, [word ptr selected]
				mov bx, offset dots
				push bx
				push di
				call array_access
				pop di
				
				mov dx, [locked_color]
				cmp [di+4], dx
				je keyboard_backspace_deselect
					mov [di+4], dx
					mov [word ptr selected], 0
					jmp sandbox_end
				keyboard_backspace_deselect:
					mov dx, [dot_color]
					mov [di+4], dx
					mov [word ptr selected], 0
					jmp sandbox_end
	
		sandbox_end:
		
		; render
		mov bx, offset real
		push bx
		mov bx, [nuclear]
		push bx
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, [dot_size]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call render
		
		; check mode
		mov bx, offset mode
		mov ax, 1
		cmp [bx], ax
		je sandbox_after
		jmp sandbox
	sandbox_after:
	
	; hide mouse
	mov ax, 2
	int 33h
	
	; deselect
	mov bx, offset dots
	push bx
	mov bx, offset saved_color
	push [word ptr bx]
	mov bx, offset selected
	push bx
	call deselect
	
	; copy dots to prev dots
	mov bx, [dot_amount]
	push bx
	mov bx, offset dots
	push bx
	mov bx, offset dots_prev
	push bx
	call copy_dots
	
	; calculate stick lengths
	mov bx, offset fpu
	push bx
	mov bx, offset sticks
	push bx
	mov bx, [stick_amount]
	push bx
	mov bx, offset dots
	push bx
	mov bx, offset sticks_length
	push bx
	call sticks_length_init
	
	; simulation loop
	simulation:
		; copy real dots positions
		mov bx, offset dots
		push bx
		mov bx, offset real
		push bx
		mov bx, [dot_amount]
		push bx
		call copy_real
		
		; simulation
		mov bx, offset dot_size
		push [word ptr bx]
		mov bx, offset gravity
		push [word ptr bx]
		mov bx, offset locked_color
		push [word ptr bx]
		mov bx, offset sticks_length
		push bx
		mov bx, offset fpu
		push bx
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call physics
		
		; render
		mov bx, offset real
		push bx
		mov bx, [nuclear]
		push bx
		mov bx, offset dots_wall_prev
		push bx
		mov bx, offset dots_prev
		push bx
		mov bx, offset dots
		push bx
		mov bx, [dot_amount]
		push bx
		mov bx, [dot_size]
		push bx
		mov bx, offset sticks
		push bx
		mov bx, [stick_amount]
		push bx
		call render
		
		call delay_physics
		
		; check if key pressed
		mov ax, 100h
		int 16h
		jz simulation
		
		; if a key is pressed, get pressed key
		mov ax, 0
		int 16h
		
		cmp al, 27
		jne simulation_no_end_program
		call escape
		simulation_no_end_program:
		cmp al, 13
		jne simulation
	
	end_program:
	mov bx, offset file_end
	push bx
	mov bx, offset file_header
	push bx
	mov bx, offset file_palette
	push bx
	mov bx, offset file_line
	push bx
	call display_bmp
	
	; show mouse
	mov ax, 1
	int 33h
	
	end_loop:
		; check for key press
		mov ax, 100h
		int 16h
		jnz after_end_loop
		
		; check for button press
		mov ax, 3
		int 33h
		sar cx, 1
		mov ax, bx
		and ax, 1b
		cmp ax, 1
		jne end_loop
			push cx dx
			mov bx, offset end_menu
			push bx
			call button
			pop bx
			
			cmp bx, 1
			jne end_loop
				jmp reset_main
	
	after_end_loop:
	; exit graphic mode
	mov ax, 2
	int 10h
	
exit:
	mov ax, 4c00h
	int 21h
END start
