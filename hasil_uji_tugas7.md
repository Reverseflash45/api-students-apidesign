# Hasil uji Tugas 7 - 2026-09-23 22:38

halaman 1: 4342417914, 4342417913, 4342417912, 4342417911, 4342417910
halaman 2: 4342417909, 4342417908, 4342417907, 4342417906, 4342417905 (duplikat: 0)
isi cursor: 1790177905072921000|29

| Bagian | Uji | Harap | Dapat | code | OK | Perintah |
|---|---|---|---|---|---|---|
| VALIDASI | POST nim/nama/grade salah | 422 | 422 | VALIDATION_ERROR | ok | `curl.exe -X POST http://localhost:3000/api/v1/students -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"nim":"a b!","name":"ab","grade":150}'` |
| VALIDASI | PATCH {"name":""} tetap diperiksa | 422 | 422 | VALIDATION_ERROR | ok | `curl.exe -X PATCH http://localhost:3000/api/v1/students/34 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":""}'` |
| VALIDASI | PATCH tanpa field apa pun | 400 | 400 | BAD_REQUEST | ok | `curl.exe -X PATCH http://localhost:3000/api/v1/students/34 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'` |
| VALIDASI | PATCH sah | 200 | 200 |  | ok | `curl.exe -X PATCH http://localhost:3000/api/v1/students/34 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"grade":91}'` |
| VALIDASI | register password terlalu pendek | 422 | 422 | VALIDATION_ERROR | ok | `curl.exe -X POST http://localhost:3000/api/v1/auth/register -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"username":"t7a","email":"t7a@unair.ac.id","password":"abc"}'` |
| VALIDASI | register password terlalu umum | 422 | 422 | VALIDATION_ERROR | ok | `curl.exe -X POST http://localhost:3000/api/v1/auth/register -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"username":"t7b","email":"t7b@unair.ac.id","password":"password123"}'` |
| VALIDASI | register password tanpa angka | 422 | 422 | VALIDATION_ERROR | ok | `curl.exe -X POST http://localhost:3000/api/v1/auth/register -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"username":"t7c","email":"t7c@unair.ac.id","password":"tanpaangka"}'` |
| NEGOSIASI | Accept: application/xml | 406 | 406 | NOT_ACCEPTABLE | ok | `curl.exe -X GET http://localhost:3000/api/v1/students?limit=3 -H "Authorization: Bearer $TOKEN" -H "Accept: application/xml"` |
| NEGOSIASI | Accept: */* | 200 | 200 |  | ok | `curl.exe -X GET http://localhost:3000/api/v1/students?limit=3 -H "Authorization: Bearer $TOKEN" -H "Accept: */*"` |
| KEGAGALAN | GET /students/999999 | 404 | 404 | NOT_FOUND | ok | `curl.exe -X GET http://localhost:3000/api/v1/students/999999 -H "Authorization: Bearer $TOKEN"` |
| KEGAGALAN | cursor rusak | 400 | 400 | BAD_REQUEST | ok | `curl.exe -X GET http://localhost:3000/api/v1/students?cursor=bukanbase64!! -H "Authorization: Bearer $TOKEN"` |
| KEGAGALAN | endpoint tidak dikenal | 404 | 404 | NOT_FOUND | ok | `curl.exe -X GET http://localhost:3000/api/v1/tidakada -H "Authorization: Bearer $TOKEN"` |
| KEGAGALAN | is_active=mungkin | 400 | 400 | BAD_REQUEST | ok | `curl.exe -X GET http://localhost:3000/api/v1/students?is_active=mungkin -H "Authorization: Bearer $TOKEN"` |
| KEGAGALAN | JSON rusak | 400 | 400 | BAD_REQUEST | ok | `curl.exe -X POST http://localhost:3000/api/v1/students -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{rusak'` |
| KEGAGALAN | tanpa token | 401 | 401 | UNAUTHORIZED | ok | `curl.exe -X GET http://localhost:3000/api/v1/students` |
| KEGAGALAN | Content-Type: text/plain | 415 | 415 | UNSUPPORTED_MEDIA_TYPE | ok | `curl.exe -X POST .../students -H "Content-Type: text/plain" -d halo` |
| INTERNAL | skema dirusak sengaja | 500 | 500 | INTERNAL_ERROR | ok | `curl.exe -X GET http://localhost:3000/api/v1/students?limit=3 -H "Authorization: Bearer $TOKEN"` |

## EXPLAIN ANALYZE
```
-- halaman 1
Limit  (cost=0.29..0.81 rows=10 width=37) (actual time=0.086..0.093 rows=10.00 loops=1)
  Buffers: shared hit=3
  ->  Index Scan using students_created_at_id_desc_idx on students  (cost=0.29..1054.78 rows=20024 width=37) (actual time=0.083..0.089 rows=10.00 loops=1)
        Index Searches: 1
        Buffers: shared hit=3
Planning:
  Buffers: shared hit=194
Planning Time: 11.776 ms
Execution Time: 0.146 ms
-- cursor
Limit  (cost=0.29..1.01 rows=10 width=37) (actual time=0.044..0.049 rows=10.00 loops=1)
  Buffers: shared hit=3
  ->  Index Scan using students_created_at_id_desc_idx on students  (cost=0.29..721.01 rows=10010 width=37) (actual time=0.042..0.045 rows=10.00 loops=1)
        Index Cond: (ROW(created_at, id) < ROW((now() - '02:46:40'::interval), 999999))
        Index Searches: 1
        Buffers: shared hit=3
Planning:
  Buffers: shared hit=193
Planning Time: 7.360 ms
Execution Time: 0.101 ms
-- OFFSET 10000
Limit  (cost=526.90..527.43 rows=10 width=37) (actual time=7.221..7.228 rows=10.00 loops=1)
  Buffers: shared hit=134
  ->  Index Scan using students_created_at_id_desc_idx on students  (cost=0.29..1054.78 rows=20024 width=37) (actual time=0.040..6.385 rows=10010.00 loops=1)
        Index Searches: 1
        Buffers: shared hit=134
Planning:
  Buffers: shared hit=194
Planning Time: 13.269 ms
Execution Time: 7.292 ms
```
