; A simple server that listens on port 1337
; When a client connects on this port
; The server will send a simple String Hello World
; To the client
; To assembly type:
; nasm -f elf32 server.asm
; ld -o server server.o
; ./server

[SECTION .data]
	msg db "Listening for incoming connections...", 0x0, 0xa
	msg_len equ $-msg

	final_mesg db "Message sent successfully", 0x0, 0xa
	final_mesg_len equ $-final_mesg

	buff db "Hello World", 0x0, 0xa
	buff_len equ $-buff

[SECTION .text]
	global _start

_start:
	; int sockfd = socket(AF_INET(2), SOCK_STREAM(1), IPPROTO_IP(0));
	; As you can see here the socket function takes 3 argument
	; AF_INET(2) is an address family that is used to designate the type of addresses 
	;         that your socket can communicate with( in this case, IPv4 addresses)
	; SOCK_STREAM(1) means TCP based communication
	; IPPROTO_IP(0) 
	; We will push the arguments of socket in reverse order into stack
	; Because stack follows LIFO rule

	push 0x66		
	pop eax				; syscall to socket
	mov ebx, 1			; SYS_SOCKET(0x1)
	
	xor esi, esi			; cleaning up esi register
	push esi			; IPPROTO_IP (0x0)
	push ebx			; SOCK_STREAM (0x1)
	push 0x2			; AF_INET (0x2)
	; ecx needs to hold the pointer to this structure
	mov ecx, esp			; save pointer to socket() args
	int 0x80			; exec SYS_SOCKET
	; After calling SYS_SOCKET it returns a socket descriptor to EAX
	; As the subsequent functions rely on this socket descriptor
	; we need to save it in an unused register from where we can pull it later
	; So we will move our socket descriptor return into EDI register
	; In our top of stack there resides 0x2
	; so first we will pop that value into edi register
	; Because 0x2 is needed for another syscall function
	pop edi				; now edi contains 0x2
	xchg edi, eax			; save result(sockfd) into edi

	;
	; bind(sockfd, const struct sockaddr *addr, socklen_t addrlen);
	;
	xchg ebx, eax				; sys_bind(0x2)
	mov al, 0x66				; syscall: sys_socketcall
	; bind takes three arguments
	; first we will create our sockaddr struct
	push esi				; sin_addr = 0 (INADDR_ANY)
	push word 0x3905			; sin_port = 1337 (network byte order)
	push word bx				; sin_family = AF_INET(0x2)
	mov ecx, esp				; save pointer to sockaddr_in struct

	push 0x10				; addrlen = 16
	push ecx				; struct sockaddr pointer
	push edi				; sockfd
	mov ecx, esp				; save pointer to bind() args
	int 0x80				; exec SYS_BIND

	; Now we need to listen for incoming connection
	; listen(sockfd, int backlog);
	mov al, 0x66				; syscall 102
	mov bl, 0x4				; sys_listen
	; listen takes 2 arguments
	push esi				; backlog = 0
	push edi				; sockfd
	mov ecx, esp				; save pointer to listen() args
	int 0x80				; exec SYS_LISTEN
	
	; we will write a simple message on our screen 
	; to confirm that it is listening for incoming connections
	; before that we must bakup our register's value to use it later
	push eax
	push ebx

	mov eax, 4				; sys_write
	mov ebx, 1				; STDOUT
	mov ecx, msg				; our message
	mov edx, msg_len			; length of our message
	int 0x80

	pop ebx
	pop eax

	; Now we need a way to accept incoming connections
	; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen)

	mov al, 0x66				; syscall : sys_socketcall
	inc ebx					; sys_accept(0x5)

	push esi				; addrlen = 0
	push esi				; addr = 0
	push edi				; sockfd
	mov ecx, esp				; save poiner to accept() args
	int 0x80				; exec sys_accept

	; after sys_accept it will return the client's socket file descriptor
	; We will save it in esi register
	mov esi, eax

	; Now we need to send our message to the client
	mov al, 0x66
	mov ebx, 0x9				; sys_send

	mov eax, 4				; SYS_WRITE
	mov ebx, esi				; write to client fd
	mov ecx, buff				; our messge
	mov edx, buff_len			; length of our message
	int 0x80				; sys_write

	; Write our final message on our screen to confirm our message has been sent
	mov eax, 4
	mov ebx, 1
	mov ecx, final_mesg
	mov edx, final_mesg_len
	int 0x80

exit:
	mov eax, 1
	xor ebx, ebx
	int 0x80
