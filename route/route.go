package route

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Reverseflash45/api-students-apidesign/app/service"
	"github.com/Reverseflash45/api-students-apidesign/helper"
	"github.com/Reverseflash45/api-students-apidesign/middleware"
)

// Dependencies mengumpulkan seluruh dependensi route menjadi satu struct.
//
// Sampai pertemuan 4, Register menerimanya sebagai parameter berderet.
// Dengan bertambahnya service, daftar itu memanjang dan setiap penambahan
// berikutnya memaksa tanda tangan function berubah, beserta semua tempat
// yang memanggilnya. Struct membuat penambahan cukup berupa satu field.
type Dependencies struct {
	Pool           *pgxpool.Pool
	JWT            *helper.JWTManager
	Permissions    *helper.PermissionSet
	StudentService *service.StudentService
	UserService    *service.UserService
	AuthService    *service.AuthService
}

// Register memetakan URL ke method pada service.
//
// Pembagiannya sengaja dibuat dapat dibaca sekilas: mana yang publik,
// mana yang untuk masuk, dan mana yang terkunci. Bila kelak seseorang
// bertanya "endpoint apa saja yang bisa diakses tanpa login", jawabannya
// cukup ditunjukkan dari berkas ini, tidak perlu menyisir seluruh
// service satu per satu.
func Register(app *fiber.App, deps Dependencies) {
	app.Get("/", func(c *fiber.Ctx) error {
		return c.SendString("Hello, World!")
	})

	api := app.Group("/api/v1")

	// ============================================================
	// PUBLIK, tidak memerlukan token
	// ============================================================
	//
	// /health sengaja dibiarkan terbuka. Endpoint kesehatan dipanggil
	// oleh load balancer dan alat pemantauan yang tidak memiliki akun,
	// dan isinya memang tidak membocorkan apa pun.
	api.Get("/health", healthCheck(deps.Pool))

	// ============================================================
	// AUTENTIKASI, pintu masuk
	// ============================================================
	auth := api.Group("/auth", middleware.RequireJSON)

	auth.Post("/register", deps.AuthService.Register)

	// Rate limiter dipasang HANYA pada login, bukan pada seluruh grup.
	// Endpoint inilah yang menjadi sasaran brute force, dan membatasi
	// endpoint lain tanpa alasan hanya mengganggu pemakai yang sah.
	auth.Post("/login", middleware.LoginRateLimiter(), deps.AuthService.Login)

	auth.Post("/refresh", deps.AuthService.Refresh)
	auth.Post("/logout", deps.AuthService.Logout)

	// /me memerlukan access token: pertanyaannya memang "siapa saya".
	auth.Get("/me", middleware.RequireAuth(deps.JWT), deps.AuthService.Me)

	// ============================================================
	// TERKUNCI, wajib membawa access token
	// ============================================================
	//
	// RequireAuth dipasang pada GRUP, bukan pada masing-masing route.
	// Bedanya menentukan: bila dipasang satu per satu, endpoint yang
	// ditambahkan kelak akan terbuka lebar hanya karena seseorang lupa
	// menuliskannya. Dipasang di grup, yang baru ikut terlindungi
	// secara bawaan.
	perms := deps.Permissions

	// ------------------------------------------------------------
	// /users, Langkah 6 Modul 6
	// ------------------------------------------------------------
	users := api.Group("/users",
		middleware.RequireJSON,
		middleware.RequireAuth(deps.JWT), // 1. siapa Anda?  (401)
	)

	// Hak dapat diputuskan tanpa melihat data -> middleware (403).
	users.Get("/",
		middleware.RequirePermission(perms, "user:list"),
		deps.UserService.List)
	users.Delete("/:id",
		middleware.RequirePermission(perms, "user:delete"),
		deps.UserService.Delete)
	users.Patch("/:id/role",
		middleware.RequirePermission(perms, "role:assign"),
		deps.UserService.AssignRole)

	// Hak bergantung pada kepemilikan -> diperiksa di SERVICE.
	// Tidak "telanjang": tetap di bawah RequireAuth milik grup.
	users.Get("/:id", deps.UserService.Get)

	// ------------------------------------------------------------
	// /students, Tugas Mandiri Modul 6
	//
	// File ini adalah PETA HAK AKSES. Urutan middleware penting:
	// RequireAuth (grup) selalu berjalan sebelum RequirePermission.
	// ------------------------------------------------------------
	students := api.Group("/students",
		middleware.RequireJSON,
		middleware.RequireAuth(deps.JWT),
	)

	// Hak dapat diputuskan tanpa melihat data -> middleware.
	students.Get("/",
		middleware.RequirePermission(perms, "student:list"),
		deps.StudentService.List)
	students.Post("/",
		middleware.RequirePermission(perms, "student:create"),
		deps.StudentService.Create)
	students.Delete("/:id",
		middleware.RequirePermission(perms, "student:delete"),
		deps.StudentService.Delete)

	// Hak bergantung pada owner_id -> diperiksa di service
	// (StudentService.authorizeStudent + CanAccessStudent).
	students.Get("/:id", deps.StudentService.Get)
	students.Put("/:id", deps.StudentService.Replace)
	students.Patch("/:id", deps.StudentService.Patch)
}

// healthCheck melaporkan kondisi layanan beserta basis datanya.
func healthCheck(pool *pgxpool.Pool) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.UserContext(), 2*time.Second)
		defer cancel()

		if err := pool.Ping(ctx); err != nil {
			return helper.ServiceUnavailable("database tidak dapat dihubungi")
		}

		return helper.Success(c, fiber.StatusOK, "server dan database berjalan", nil)
	}
}
