# Nome do arquivo executável
TARGET = iolib

# Compilador e flags
ASM = nasm
ASMFLAGS = -f elf64

LD = ld
LDFLAGS = 

# Regra padrão
all: $(TARGET)

# Compilação
$(TARGET): $(TARGET).o
	$(LD) $(LDFLAGS) -o $@ $^

# Montagem
%.o: %.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

# Limpeza
clean:
	rm -f *.o $(TARGET)
