#pragma once
#include "utility.h"
#include <bit>

enum class PackageType : byte {
	PING = 0x00,
	GET_PC = 0x01, // may not work
	PAUSE_RUN = 0x03,
	START_RUN = 0x04,
	UPLOAD_INPUT = 0x05,
	GET_RAM = 0x09, // may not work
	UPLOAD_RAM = 0x0A,
};

#pragma pack(push, 1)

// Thanks to @DarkSharpness
static_assert(std::endian::native == std::endian::little, "big endian not supported");

// debug packet format: see hci.v or README.md
struct PackagePING {
	PackageType const type = PackageType::PING;
	hword size;
	byte data[32];

	size_t package_length() const {
		return sizeof(type) + sizeof(size) + size;
	}
};

struct PackageUploadRAM {
	PackageType const type = PackageType::UPLOAD_RAM;
	dword addr : 24 = 0;
	dword size : 16 = 0;
	byte buff[1024] = {};
	PackageUploadRAM(dword start_addr, byte const *data, size_t size)
		: addr(start_addr), size(size) {
		assert(size <= sizeof(buff), "ram data size exceeds buffer size");
		memcpy(buff, data, size);
	}
	size_t package_length() const {
		return 6 + size;
	}
};

struct PackageUploadInput {
	PackageType const type = PackageType::UPLOAD_INPUT;
	hword size = 0; // 2 bytes
	byte data[1024] = {};

	PackageUploadInput(byte const *data, size_t size) : size(size) {
		assert(size <= sizeof(this->data), "input data size exceeds buffer size");
		memcpy(this->data, data, size);
	}

	size_t package_length() const {
		return sizeof(type) + sizeof(size) + size;
	}
};

struct PackageGetRAM {
	PackageType const type = PackageType::GET_RAM;
	dword addr : 24 = 0;
	dword size : 16 = 0;
	PackageGetRAM(dword start_addr, hword size) : addr(start_addr), size(size) {}
	size_t package_length() const {
		return sizeof(PackageGetRAM);
	}
};

#pragma pack(pop)
