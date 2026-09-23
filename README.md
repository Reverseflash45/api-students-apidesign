# api-students-apidesign (Praktikum Backend Lanjut Pertemuan 7)

Advanced API Design. Lanjutan `api-students-rbac` (pertemuan 6).

**Rafi Fernandito Setiawan, 434241117, D4 Teknik Informatika, Fakultas Vokasi, Universitas Airlangga**

## Menjalankan

```powershell
Copy-Item ..\api-students-rbac\.env .env
$env:PGPASSWORD = "praktikum123"
psql -U postgres -d praktikum_backend -f migrations/005_cursor_index.sql
go get github.com/go-playground/validator/v10
go mod tidy
go test ./...
go run .
```

## Yang berubah dari Modul 6

| Bagian | Sebelum | Sekarang |
|---|---|---|
| Validasi | rangkaian `if` di `*_rules.go` | tag `validate:` pada struct request |
| Kegagalan | `helper.Fail` di puluhan tempat | handler `return` error, satu `ErrorHandler` |
| Bentuk kegagalan | `errors` | `code` + `message` + `fields` + `request_id` |
| Daftar | `LIMIT/OFFSET` + `total_pages` | keyset (cursor) + `next_cursor` + `has_more` |
| Format | JSON saja | JSON dan CSV lewat header `Accept` |

## Berkas baru / berubah

```
helper/errors.go        BARU  AppError + konstruktor per kode error
helper/validator.go     BARU  validator sekali pakai, custom tag, penerjemah pesan
helper/cursor.go        BARU  Encode/DecodeCursor + ParseCursorQuery
helper/negotiate.go     BARU  Negotiate + penulis CSV
helper/response.go      UBAH  SuccessCursor; Fail & FailValidation DIHAPUS
config/app.go           UBAH  ErrorHandler terpusat, 4xx WARN / 5xx ERROR
middleware/*            UBAH  mengembalikan AppError; access log memakai status terkoreksi
app/model/*             UBAH  tag validate, Cursor/CursorQuery/CursorMeta, ErrorResponse
app/repository/*        UBAH  FindAfterCursor (keyset, limit+1)
app/service/*           UBAH  seluruh method mengembalikan error
migrations/005_cursor_index.sql  BARU  index (created_at DESC, id DESC)
uji_tugas7.ps1          BARU  pengujian Spesifikasi Penerimaan + EXPLAIN ANALYZE
```

## Kode error

| code | status | situasi |
|---|---|---|
| `VALIDATION_ERROR` | 422 | aturan tag dilanggar |
| `BAD_REQUEST` | 400 | JSON rusak, cursor rusak, `is_active` bukan boolean, PATCH kosong, id bukan angka |
| `UNAUTHORIZED` | 401 | token tidak ada, tidak sah, atau kedaluwarsa |
| `FORBIDDEN` | 403 | role tidak punya permission, atau bukan pemilik data |
| `NOT_FOUND` | 404 | id tidak ada, endpoint tidak dikenal |
| `CONFLICT` | 409 | NIM atau username sudah dipakai |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | `Content-Type` bukan `application/json` |
| `NOT_ACCEPTABLE` | 406 | `Accept` tidak dapat dipenuhi |
| `TOO_MANY_REQUESTS` | 429 | rate limiter login |
| `PAYLOAD_TOO_LARGE` | 413 | body melebihi 1 MB |
| `INTERNAL_ERROR` | 500 | kegagalan tak terduga; pesan aslinya hanya ke log |
| `SERVICE_UNAVAILABLE` | 503 | database tidak dapat dihubungi |
