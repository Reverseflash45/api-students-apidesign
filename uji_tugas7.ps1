# ================================================================
# uji_tugas7.ps1: pengujian Spesifikasi Penerimaan Modul 7
# Jalankan dari folder api-students-apidesign, server harus sudah menyala.
#   powershell -ExecutionPolicy Bypass -File .\uji_tugas7.ps1
# ================================================================
$ErrorActionPreference = 'Continue'
$B    = 'http://localhost:3000/api/v1'
$DB   = 'praktikum_backend'
$PASS = 'Rahasia123!'
$env:PGPASSWORD = 'praktikum123'
$tmpBody = Join-Path $env:TEMP 't7_body.json'
$tmpOut  = Join-Path $env:TEMP 't7_out.txt'
$hasil   = New-Object System.Collections.ArrayList
$TOKEN   = ''

function Sql([string]$q) { (& psql -h localhost -U postgres -d $DB -tAc $q 2>&1 | Out-String).Trim() }
function Tulis([string]$path, [string]$isi) { [IO.File]::WriteAllText($path, $isi) }

# Req: kirim satu request, catat status, bandingkan dengan yang diharapkan.
function Req([string]$bagian, [string]$label, [string]$method, [string]$path, [string]$body, [int]$harap, [string]$accept) {
    if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force }
    $a   = @('-s', '-o', $tmpOut, '-w', '%{http_code}', '-X', $method, "$B$path")
    $cmd = "curl.exe -X $method $B$path"
    if ($TOKEN) { $a += @('-H', "Authorization: Bearer $TOKEN"); $cmd += ' -H "Authorization: Bearer $TOKEN"' }
    if ($accept) { $a += @('-H', "Accept: $accept"); $cmd += " -H `"Accept: $accept`"" }
    if ($body) {
        Tulis $tmpBody $body
        $a   += @('-H', 'Content-Type: application/json', '--data-binary', "@$tmpBody")
        $cmd += " -H `"Content-Type: application/json`" -d '$body'"
    }
    $code = [int](& curl.exe @a)
    $resp = ''
    if (Test-Path $tmpOut) { $resp = [IO.File]::ReadAllText($tmpOut) }
    $kode = ''
    try { $kode = ($resp | ConvertFrom-Json).code } catch { }
    $ok = if ($code -eq $harap) { 'ok' } else { 'SALAH' }
    [void]$hasil.Add([pscustomobject]@{ Bagian=$bagian; Uji=$label; Harap=$harap; Dapat=$code; Code=$kode; OK=$ok; Curl=$cmd })
    $warna = if ($ok -eq 'ok') { 'Green' } else { 'Red' }
    Write-Host ("{0,-46} {1} (harap {2}) {3}" -f $label, $code, $harap, $kode) -ForegroundColor $warna
    return $resp
}

function Get-Json([string]$path) {
    $a = @('-s', "$B$path")
    if ($TOKEN) { $a += @('-H', "Authorization: Bearer $TOKEN") }
    return (& curl.exe @a | ConvertFrom-Json)
}

# ---------------------------------------------------------------
Write-Host "`n== PERSIAPAN ==" -ForegroundColor Cyan
Tulis $tmpBody "{`"username`":`"t7admin`",`"email`":`"t7admin@unair.ac.id`",`"password`":`"$PASS`"}"
& curl.exe -s -o NUL -X POST "$B/auth/register" -H 'Content-Type: application/json' --data-binary "@$tmpBody" | Out-Null
Sql "UPDATE users SET role='admin' WHERE username='t7admin';" | Out-Null
Tulis $tmpBody "{`"username`":`"t7admin`",`"password`":`"$PASS`"}"
$login = & curl.exe -s -X POST "$B/auth/login" -H 'Content-Type: application/json' --data-binary "@$tmpBody"
$TOKEN = ($login | ConvertFrom-Json).data.access_token
if (-not $TOKEN) { Write-Host "LOGIN GAGAL: $login" -ForegroundColor Red; exit 1 }
Write-Host "login t7admin berhasil"

Sql "DELETE FROM students WHERE nim LIKE '4342417%';" | Out-Null
foreach ($i in 1..14) {
    $nim = '43424179{0:d2}' -f $i
    Tulis $tmpBody "{`"nim`":`"$nim`",`"name`":`"Uji Tujuh $i`",`"grade`":80}"
    & curl.exe -s -o NUL -X POST "$B/students" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary "@$tmpBody" | Out-Null
}
Write-Host "14 data uji dibuat"

# ---------------------------------------------------------------
Write-Host "`n== C.1 CURSOR PAGINATION ==" -ForegroundColor Cyan
$p1 = Get-Json "/students?limit=5"
Write-Host ("hal 1 : " + (($p1.data | ForEach-Object { $_.nim }) -join ', '))
Write-Host ("meta  : limit=$($p1.meta.limit) has_more=$($p1.meta.has_more) next_cursor=$($p1.meta.next_cursor)")
$cur = $p1.meta.next_cursor
$isiCursor = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($cur.PadRight([int](([math]::Ceiling($cur.Length / 4)) * 4), '=')))
Write-Host "isi cursor (base64 BUKAN enkripsi): $isiCursor" -ForegroundColor Yellow

Write-Host "`n-- sisipkan satu baris baru yang akan menempati posisi teratas --"
Tulis $tmpBody '{"nim":"434241799","name":"Baris Baru","grade":90}'
& curl.exe -s -o NUL -X POST "$B/students" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary "@$tmpBody" | Out-Null
$p2 = Get-Json "/students?limit=5&cursor=$cur"
Write-Host ("hal 2 : " + (($p2.data | ForEach-Object { $_.nim }) -join ', '))
$dup = @($p1.data | ForEach-Object { $_.nim } | Where-Object { $p2.data.nim -contains $_ })
if ($dup.Count -eq 0) { Write-Host "tidak ada baris yang muncul dua kali" -ForegroundColor Green }
else { Write-Host "DUPLIKAT: $($dup -join ', ')" -ForegroundColor Red }

$akhir = Get-Json "/students?limit=50"
Write-Host ("halaman penuh: $($akhir.data.Count) baris, has_more=$($akhir.meta.has_more), next_cursor kosong = " + [string]::IsNullOrEmpty($akhir.meta.next_cursor))
$besar = Get-Json "/students?limit=1000"
Write-Host "limit=1000 dibatasi menjadi $($besar.meta.limit) (helper/cursor.go, cursorLimitMaks)"

# ---------------------------------------------------------------
Write-Host "`n== C.3 VALIDASI DEKLARATIF ==" -ForegroundColor Cyan
$r = Req 'VALIDASI' 'POST nim/nama/grade salah'     POST '/students' '{"nim":"a b!","name":"ab","grade":150}' 422 ''
Write-Host ("   fields: " + (($r | ConvertFrom-Json).fields | ConvertTo-Json -Compress))
$sid = Sql "SELECT id FROM students WHERE nim='434241799'"
Req 'VALIDASI' 'PATCH {"name":""} tetap diperiksa'  PATCH "/students/$sid" '{"name":""}' 422 '' | Out-Null
Req 'VALIDASI' 'PATCH tanpa field apa pun'          PATCH "/students/$sid" '{}' 400 '' | Out-Null
Req 'VALIDASI' 'PATCH sah'                          PATCH "/students/$sid" '{"grade":91}' 200 '' | Out-Null
Req 'VALIDASI' 'register password terlalu pendek'   POST '/auth/register' '{"username":"t7a","email":"t7a@unair.ac.id","password":"abc"}' 422 '' | Out-Null
$r = Req 'VALIDASI' 'register password terlalu umum' POST '/auth/register' '{"username":"t7b","email":"t7b@unair.ac.id","password":"password123"}' 422 ''
Write-Host ("   fields: " + (($r | ConvertFrom-Json).fields | ConvertTo-Json -Compress))
Req 'VALIDASI' 'register password tanpa angka'      POST '/auth/register' '{"username":"t7c","email":"t7c@unair.ac.id","password":"tanpaangka"}' 422 '' | Out-Null

# ---------------------------------------------------------------
Write-Host "`n== C.4 CONTENT NEGOTIATION ==" -ForegroundColor Cyan
& curl.exe -s -D $tmpOut -o (Join-Path $env:TEMP 't7.csv') "$B/students?limit=3" -H "Authorization: Bearer $TOKEN" -H 'Accept: text/csv' | Out-Null
Get-Content $tmpOut | Where-Object { $_ -match 'Content-Type|Content-Disposition' } | ForEach-Object { Write-Host $_ }
Get-Content (Join-Path $env:TEMP 't7.csv') | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
Req 'NEGOSIASI' 'Accept: application/xml'  GET '/students?limit=3' '' 406 'application/xml' | Out-Null
Req 'NEGOSIASI' 'Accept: */*'              GET '/students?limit=3' '' 200 '*/*' | Out-Null

# ---------------------------------------------------------------
Write-Host "`n== C.5 KESERAGAMAN RESPONSE KEGAGALAN ==" -ForegroundColor Cyan
Req 'KEGAGALAN' 'GET /students/999999'          GET    '/students/999999' '' 404 '' | Out-Null
Req 'KEGAGALAN' 'cursor rusak'                  GET    '/students?cursor=bukanbase64!!' '' 400 '' | Out-Null
Req 'KEGAGALAN' 'endpoint tidak dikenal'        GET    '/tidakada' '' 404 '' | Out-Null
Req 'KEGAGALAN' 'is_active=mungkin'             GET    '/students?is_active=mungkin' '' 400 '' | Out-Null
Req 'KEGAGALAN' 'JSON rusak'                    POST   '/students' '{rusak' 400 '' | Out-Null
$simpan = $TOKEN; $TOKEN = ''
Req 'KEGAGALAN' 'tanpa token'                   GET    '/students' '' 401 '' | Out-Null
$TOKEN = $simpan
if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force }
$c415 = [int](& curl.exe -s -o $tmpOut -w '%{http_code}' -X POST "$B/students" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: text/plain' -d 'halo')
[void]$hasil.Add([pscustomobject]@{ Bagian='KEGAGALAN'; Uji='Content-Type: text/plain'; Harap=415; Dapat=$c415; Code='UNSUPPORTED_MEDIA_TYPE'; OK=$(if($c415 -eq 415){'ok'}else{'SALAH'}); Curl='curl.exe -X POST .../students -H "Content-Type: text/plain" -d halo' })
Write-Host ("{0,-46} {1} (harap 415)" -f 'Content-Type: text/plain', $c415) -ForegroundColor $(if($c415 -eq 415){'Green'}else{'Red'})

# ---------------------------------------------------------------
Write-Host "`n== C.6 KEGAGALAN SERVER TIDAK MEMBOCORKAN DETAIL ==" -ForegroundColor Cyan
Sql "ALTER TABLE students RENAME COLUMN name TO name_x;" | Out-Null
$r = Req 'INTERNAL' 'skema dirusak sengaja'     GET '/students?limit=3' '' 500 ''
Write-Host ("   body ke client: " + $r.Trim())
Sql "ALTER TABLE students RENAME COLUMN name_x TO name;" | Out-Null
Write-Host "   baris log (HANYA di sini pesan aslinya muncul):"
if (Test-Path .\logs\app.log) {
    Get-Content .\logs\app.log -Tail 40 | Where-Object { $_ -match 'request_failed' } | Select-Object -Last 1 | ForEach-Object { Write-Host ("   " + $_) -ForegroundColor Yellow }
}

Write-Host "`n== C.7 TINGKAT LOG ==" -ForegroundColor Cyan
if (Test-Path .\logs\app.log) {
    Get-Content .\logs\app.log -Tail 60 | Where-Object { $_ -match 'request_rejected|request_failed' } | Select-Object -Last 6 | ForEach-Object {
        $o = $_ | ConvertFrom-Json
        Write-Host ("   {0,-6} {1,-18} status={2} path={3}" -f $o.level, $o.msg, $o.status, $o.path)
    }
}

# ---------------------------------------------------------------
Write-Host "`n== EXPLAIN ANALYZE ==" -ForegroundColor Cyan
Write-Host "menyiapkan 20.000 baris beban uji..."
Sql "INSERT INTO students (nim,name,grade,is_active,created_at) SELECT '9'||lpad(i::text,8,'0'), 'Beban Uji '||i, 70, true, NOW() - (i || ' seconds')::interval FROM generate_series(1,20000) i ON CONFLICT DO NOTHING; ANALYZE students;" | Out-Null
$e1 = Sql "EXPLAIN ANALYZE SELECT id,nim,name FROM students ORDER BY created_at DESC, id DESC LIMIT 10;"
$e2 = Sql "EXPLAIN ANALYZE SELECT id,nim,name FROM students WHERE (created_at,id) < (NOW() - interval '10000 seconds', 999999) ORDER BY created_at DESC, id DESC LIMIT 10;"
$e3 = Sql "EXPLAIN ANALYZE SELECT id,nim,name FROM students ORDER BY created_at DESC, id DESC LIMIT 10 OFFSET 10000;"
Write-Host "--- halaman 1 (tanpa cursor)"; Write-Host $e1
Write-Host "--- halaman lanjut (cursor)";  Write-Host $e2
Write-Host "--- pembanding OFFSET 10000";  Write-Host $e3
Sql "DELETE FROM students WHERE name LIKE 'Beban Uji %'; ANALYZE students;" | Out-Null
Write-Host "beban uji dihapus kembali"

# ---------------------------------------------------------------
Write-Host "`n== TIDAK ADA LAGI helper.Fail ==" -ForegroundColor Cyan
# dicari pemanggilannya (ada tanda kurung), bukan komentar yang menyebut namanya
$sisa = Select-String -Path (Get-ChildItem -Recurse -Filter *.go | ForEach-Object { $_.FullName }) -Pattern 'helper\.Fail\(|FailValidation\('
if ($sisa) { $sisa | ForEach-Object { Write-Host $_.Line -ForegroundColor Red } }
else { Write-Host "grep bersih: tidak ada helper.Fail / FailValidation tersisa" -ForegroundColor Green }

# ---------------------------------------------------------------
$salah = @($hasil | Where-Object { $_.OK -ne 'ok' }).Count
Write-Host "`n== RINGKASAN: $($hasil.Count) uji, $salah salah ==" -ForegroundColor $(if ($salah -eq 0) { 'Green' } else { 'Red' })

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Hasil uji Tugas 7 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$md.AppendLine("")
[void]$md.AppendLine("halaman 1: " + (($p1.data | ForEach-Object { $_.nim }) -join ', '))
[void]$md.AppendLine("halaman 2: " + (($p2.data | ForEach-Object { $_.nim }) -join ', ') + " (duplikat: $($dup.Count))")
[void]$md.AppendLine("isi cursor: $isiCursor")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Bagian | Uji | Harap | Dapat | code | OK | Perintah |")
[void]$md.AppendLine("|---|---|---|---|---|---|---|")
foreach ($h in $hasil) { [void]$md.AppendLine("| $($h.Bagian) | $($h.Uji) | $($h.Harap) | $($h.Dapat) | $($h.Code) | $($h.OK) | ``$($h.Curl)`` |") }
[void]$md.AppendLine("")
[void]$md.AppendLine("## EXPLAIN ANALYZE")
[void]$md.AppendLine('```'); [void]$md.AppendLine("-- halaman 1"); [void]$md.AppendLine($e1)
[void]$md.AppendLine("-- cursor");    [void]$md.AppendLine($e2)
[void]$md.AppendLine("-- OFFSET 10000"); [void]$md.AppendLine($e3); [void]$md.AppendLine('```')
Tulis (Join-Path (Get-Location) 'hasil_uji_tugas7.md') $md.ToString()
Write-Host "Tabel lengkap ditulis ke hasil_uji_tugas7.md"
