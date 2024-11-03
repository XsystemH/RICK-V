#pragma once
#include "package.h"
#include "uart.h"
#include "utility.h"
#include <algorithm>
#include <cstddef>
#include <cstring>

class Controller {
	Serial &serPort;

public:
	Controller(Serial &_serPort) : serPort(_serPort) {}

	void ping_pong_test() {
		std::string const test_str = "UART";
		hword len = static_cast<hword>(test_str.size());
		PackagePING ping = {PackageType::PING, len};
		memcpy(ping.data, test_str.data(), len);
		serPort.write(ping);
		auto response = serPort.read(len);
		debug::assert(response == test_str,
					  "PING test failed: expected {}, got {}\n", test_str.c_str(), response.c_str());
	}

	void upload_ram(std::vector<byte> const &data) {
		if (data.empty())
			throw std::runtime_error("empty ram data");

		constexpr size_t BLOCK_SIZE = 1024;
		for (size_t addr = 0; addr < data.size(); addr += BLOCK_SIZE) {
			auto k = std::min(BLOCK_SIZE, static_cast<size_t>(data.size() - addr));
			PackageUploadRAM pkg(addr, data.data() + addr, k);
			serPort.write(pkg);
		}
		info("RAM uploaded\n");
	}

	void upload_input(std::vector<byte> const &data) {
		if (data.empty()) return;

		// old code, i don't know why. seems ok without this
		// char const *strange_pad_data = "  ";
		// PackageUploadInput pkg((byte *) strange_pad_data, 2);
		// serPort.write(pkg);

		constexpr size_t BLOCK_SIZE = 64;
		for (auto cur = data.begin(); cur < data.end(); cur += BLOCK_SIZE) {
			auto k = std::min(BLOCK_SIZE, static_cast<size_t>(data.end() - cur));
			PackageUploadInput pkg(&*cur, k);
			serPort.write(pkg);
		}
		info("INPUT uploaded\n");
	}

	void verify_ram(std::vector<byte> const &data) {
		constexpr size_t BLOCK_SIZE = 1024;
		std::vector<byte> recv_data(BLOCK_SIZE);
		for (size_t addr = 0; addr < data.size(); addr += BLOCK_SIZE) {
			auto k = std::min(BLOCK_SIZE, static_cast<size_t>(data.size() - addr));
			PackageGetRAM pkg(addr, k);
			serPort.write(pkg);
			auto ret = serPort.read(recv_data.data(), k);
			if (!std::equal(data.begin() + addr, data.begin() + addr + k, recv_data.begin())) {
				auto msg = std::format("RAM verification failed at address [{:x}, {:x})", addr, addr + k);
				throw std::runtime_error(msg);
			}
		}
		info("RAM verified\n");
	}

	dword get_pc() {
		serPort.write(PackageType::GET_PC);
		dword pc = 0;
		serPort.read(reinterpret_cast<byte *>(&pc), sizeof(pc));
		return pc;
	}

	void start_run() {
		serPort.write(PackageType::START_RUN);
	}
	void pause_run() {
		serPort.write(PackageType::PAUSE_RUN);
	}
	bool output_available() {
		return serPort.available();
	}
	char get_output() {
		byte data;
		serPort.read(&data, 1);
		return data;
	}
};