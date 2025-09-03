# --- Variáveis de Configuração ---
$InstallDir = "C:\msys64" 
$InstallerUrl = "https://github.com/msys2/msys2-installer/releases/download/2024-01-13/msys2-x86_64-20240113.exe"
$InstallerName = "msys2-installer.exe"
$InstallerPath = Join-Path $env:TEMP $InstallerName


Write-Host "Iniciando a instalação e configuração automatizada do MSYS2..." -ForegroundColor Green
Write-Host "Verificando privilégios de Administrador..."

# # Verifica se o script está rodando como Administrador
# if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
#     Write-Host "ERRO: Este script precisa ser executado com privilégios de Administrador." -ForegroundColor Red
#     Write-Host "Por favor, abra o PowerShell com 'Executar como Administrador' e tente novamente." -ForegroundColor Red
#     exit 1
# }
# Write-Host "Privilégios de Administrador confirmados." -ForegroundColor Cyan


# --- Passo 1: Baixar o Instalador ---
try {
    Write-Host "Baixando o instalador do MSYS2..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "Download concluído." -ForegroundColor Cyan
}
catch {
    Write-Host "ERRO: Falha ao baixar o instalador." -ForegroundColor Red
    exit 1
}

# --- Passo 2: Instalação Silenciosa ---
Write-Host "Instalando o MSYS2 em '$InstallDir'..."

Start-Process -FilePath $InstallerPath -ArgumentList @("/S", "/D=$InstallDir") -Wait

Write-Host "Instalação concluída." -ForegroundColor Cyan

# --- Passo 2.5: Verificação da Instalação ---
$Ucrt64Shell = Join-Path $InstallDir 'ucrt64.exe'
if (-not (Test-Path $Ucrt64Shell)) {
    Write-Host "ERRO CRÍTICO: A instalação falhou. O arquivo '$Ucrt64Shell' não foi encontrado." -ForegroundColor Red
    Write-Host "Verifique se há erros no log do sistema ou tente a instalação manual." -ForegroundColor Red
    exit 1
}
Write-Host "Verificação da instalação bem-sucedida." -ForegroundColor Green

# --- Passo 3: Atualizar Pacotes Base ---
Write-Host "Atualizando pacotes base do MSYS2 (passo 1/2)..."
Start-Process -FilePath $Ucrt64Shell -ArgumentList "-c 'pacman -Syu --noconfirm --noconfirm'" -Wait
Write-Host "Atualizando pacotes base do MSYS2 (passo 2/2)..."
Start-Process -FilePath $Ucrt64Shell -ArgumentList "-c 'pacman -Su --noconfirm --noconfirm'" -Wait
Write-Host "Pacotes base atualizados." -ForegroundColor Cyan

# --- Passo 4: Instalar a Toolchain de Desenvolvimento ---
Write-Host "Instalando a toolchain de desenvolvimento (GCC, make, etc.)... Isso pode demorar alguns minutos."
$InstallCommand = "pacman -S --needed base-devel mingw-w64-ucrt-x86_64-toolchain --noconfirm"
Start-Process -FilePath $Ucrt64Shell -ArgumentList "-c '$InstallCommand'" -Wait
Write-Host "Toolchain instalada com sucesso." -ForegroundColor Cyan

# --- Passo 5: Criar o atalho para 'make.exe' ---
$BinPath = Join-Path $InstallDir "ucrt64\bin"
$SourceMake = Join-Path $BinPath "mingw32-make.exe"
$DestMake = Join-Path $BinPath "make.exe"
$GccExe = Join-Path $BinPath "gcc.exe"

Write-Host "Verificando se as ferramentas foram instaladas corretamente..."
if (Test-Path $GccExe) {
    Write-Host "GCC encontrado: $GccExe" -ForegroundColor Cyan
} else {
    Write-Host "AVISO: GCC não encontrado em $GccExe" -ForegroundColor Yellow
}

if (Test-Path $SourceMake) {
    Write-Host "mingw32-make.exe encontrado: $SourceMake" -ForegroundColor Cyan
    Write-Host "Criando o atalho 'make.exe' para 'mingw32-make.exe'..."
    Copy-Item -Path $SourceMake -Destination $DestMake -Force
    Write-Host "'make.exe' criado com sucesso." -ForegroundColor Cyan
} else {
    Write-Host "AVISO: 'mingw32-make.exe' não encontrado em $SourceMake" -ForegroundColor Yellow
}

# --- Passo 6: Adicionar ao PATH do Usuário ---
Write-Host "Adicionando '$BinPath' ao PATH do usuário..."
$CurrentUserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($CurrentUserPath -notlike "*$BinPath*") {
    $NewPath = ($CurrentUserPath, $BinPath) -join ';'
    [System.Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    Write-Host "PATH do usuário atualizado com sucesso." -ForegroundColor Cyan
} else {
    Write-Host "O caminho do MSYS2 já existe no PATH do usuário. Nenhuma alteração foi feita." -ForegroundColor Yellow
}

# --- Atualizar PATH da sessão atual ---
Write-Host "Atualizando PATH da sessão atual..."
$env:Path = "$env:Path;$BinPath"
Write-Host "PATH da sessão atual atualizado." -ForegroundColor Cyan

# --- Passo 7: Teste das ferramentas ---
Write-Host "Testando as ferramentas instaladas..."
try {
    Write-Host "Testando GCC..."
    $gccVersion = & gcc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "GCC funcional: $(($gccVersion -split "`n")[0])" -ForegroundColor Green
    } else {
        Write-Host "ERRO: GCC não está funcionando." -ForegroundColor Red
    }
} catch {
    Write-Host "ERRO: Não foi possível executar gcc --version" -ForegroundColor Red
}

try {
    Write-Host "Testando Make..."
    $makeVersion = & make --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Make funcional: $(($makeVersion -split "`n")[0])" -ForegroundColor Green
    } else {
        Write-Host "ERRO: Make não está funcionando." -ForegroundColor Red
    }
} catch {
    Write-Host "ERRO: Não foi possível executar make --version" -ForegroundColor Red
}

# --- Passo 8: Limpeza ---
Write-Host "Limpando o instalador..."
Remove-Item $InstallerPath -ErrorAction SilentlyContinue

Write-Host "--------------------------------------------------------" -ForegroundColor Green
Write-Host "Instalação do MSYS2 concluída com sucesso!" -ForegroundColor Green
Write-Host "O PATH foi atualizado para a sessão atual e para futuras sessões." -ForegroundColor Green
Write-Host "Você já pode usar gcc e make neste terminal!" -ForegroundColor Yellow