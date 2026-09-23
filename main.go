package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Reverseflash45/api-students-apidesign/app/repository"
	"github.com/Reverseflash45/api-students-apidesign/app/service"
	"github.com/Reverseflash45/api-students-apidesign/config"
	"github.com/Reverseflash45/api-students-apidesign/database"
	"github.com/Reverseflash45/api-students-apidesign/helper"
	"github.com/Reverseflash45/api-students-apidesign/route"
)

// minSecretLength = 32 karakter.
//
// Secret HS256 yang pendek dapat ditebak dengan mencoba kata demi kata
// terhadap satu token yang pernah terlihat, dan token memang beredar
// bebas, itu memang gunanya. Begitu secret ditemukan, penyerang bukan
// hanya bisa masuk: ia bisa MEMBUAT token untuk siapa pun, dengan role
// apa pun, tanpa perlu satu akun pun.
const minSecretLength = 32

// main hanya berisi urutan perakitan. Tidak ada logika bisnis,
// tidak ada query, dan tidak ada satu pun handler di sini.
func main() {
	// ============================================================
	// 1. Konfigurasi dan logger
	// ============================================================
	config.LoadEnv()
	logger := config.NewLogger()

	// ============================================================
	// 2. Pemeriksaan rahasia, SEBELUM server menyala
	// ============================================================
	//
	// Sengaja tidak ada nilai bawaan untuk JWT_SECRET. Nilai bawaan pada
	// secret adalah pola kegagalan yang klasik: aplikasi tetap menyala,
	// semuanya tampak bekerja, dan tidak ada satu pun tanda bahwa seluruh
	// token dapat dipalsukan siapa saja yang pernah membaca kode ini.
	//
	// Gagal seketika dengan pesan yang jelas jauh lebih baik daripada
	// berjalan dengan keamanan yang diam-diam tidak ada.
	jwtSecret := config.GetEnv("JWT_SECRET", "")
	if len(jwtSecret) < minSecretLength {
		logger.Error("JWT_SECRET tidak diisi atau terlalu pendek",
			slog.Int("minimal_karakter", minSecretLength),
			slog.Int("panjang_sekarang", len(jwtSecret)),
		)
		os.Exit(1)
	}

	// ============================================================
	// 3. Basis data
	// ============================================================
	pool, err := database.NewPool(context.Background())
	if err != nil {
		logger.Error("gagal terhubung ke database", slog.String("error", err.Error()))
		os.Exit(1)
	}
	defer pool.Close()

	// ============================================================
	// 4. Perakitan dari dalam ke luar
	// ============================================================
	jwtManager := helper.NewJWTManager(
		jwtSecret,
		config.GetEnv("JWT_ISSUER", "praktikum-backend"),
		time.Duration(config.GetEnvInt("JWT_ACCESS_TTL_MINUTES", 15))*time.Minute,
	)

	studentRepository := repository.NewStudentRepository(pool)
	userRepository := repository.NewUserRepository(pool)
	tokenRepository := repository.NewTokenRepository(pool)
	roleRepository := repository.NewRoleRepository(pool)

	// Pemetaan role -> permission dibaca SEKALI saat aplikasi menyala.
	// Akibatnya: perubahan di table role_permissions baru berlaku setelah
	// aplikasi dijalankan ulang. Keputusan sadar, bukan kelalaian.
	//
	// Gagal memuat = aplikasi menolak menyala. PermissionSet kosong akan
	// membuat SEMUA endpoint menjawab 403, membingungkan dan sulit
	// didiagnosis. Lebih baik gagal keras di detik pertama.
	rawPermissions, err := roleRepository.LoadPermissions(context.Background())
	if err != nil {
		logger.Error("gagal memuat permission", slog.String("error", err.Error()))
		os.Exit(1)
	}
	permissions := helper.NewPermissionSet(rawPermissions)
	logger.Info("permission dimuat", slog.Any("roles", permissions.KnownRoles()))

	studentService := service.NewStudentService(studentRepository, permissions)
	userService := service.NewUserService(userRepository, permissions)
	authService := service.NewAuthService(
		userRepository,
		tokenRepository,
		jwtManager,
		permissions,
		time.Duration(config.GetEnvInt("JWT_REFRESH_TTL_DAYS", 7))*24*time.Hour,
	)

	// ============================================================
	// 5. Aplikasi
	// ============================================================
	app := config.NewApp(logger, route.Dependencies{
		Pool:           pool,
		JWT:            jwtManager,
		Permissions:    permissions,
		StudentService: studentService,
		UserService:    userService,
		AuthService:    authService,
	})

	port := config.GetEnv("APP_PORT", "3000")

	go func() {
		if err := app.Listen(":" + port); err != nil {
			logger.Error("server berhenti", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()

	logger.Info("server berjalan", slog.String("port", port))

	// ============================================================
	// 6. Graceful shutdown
	// ============================================================
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("sinyal berhenti diterima, menutup server")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := app.ShutdownWithContext(ctx); err != nil {
		logger.Error("gagal menutup server dengan rapi",
			slog.String("error", err.Error()))
	}

	logger.Info("server berhenti dengan rapi")
}
