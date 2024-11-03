#pragma once
#include "package.h"
#include "utility.h"
#include <serial/serial.h>

namespace config {

static constexpr int baud_rate = 115200;
static constexpr serial::bytesize_t byte_size = serial::eightbits;
static constexpr serial::parity_t parity = serial::parity_odd;
static constexpr serial::stopbits_t stopbits = serial::stopbits_one;
static constexpr int inter_byte_timeout = 50;
static constexpr int read_timeout_constant = 50;
static constexpr int read_timeout_multiplier = 10;
static constexpr int write_timeout_constant = 50;
static constexpr int write_timeout_multiplier = 10;

} // namespace config

class Serial : public serial::Serial {
public:
	void init_port(char *port) {
		using namespace config;
		this->setPort(port);
		this->setBaudrate(baud_rate);
		this->setBytesize(byte_size);
		this->setParity(parity);
		this->setStopbits(stopbits);
		this->setTimeout(
				inter_byte_timeout,
				read_timeout_constant,
				read_timeout_multiplier,
				write_timeout_constant,
				write_timeout_multiplier);
		this->open();
		info("initialized UART port on: {}\n", port);
		// old code, i don't know why. seems ok without this
		// byte junk[8];
		// this->read(junk, 8);
	}

	template<typename _Pkg>
		requires requires(_Pkg t) { { t.package_length() } -> std::integral; }
	void write(_Pkg const &pkg) {
		auto addr = reinterpret_cast<byte const *>(&pkg);
		auto size = pkg.package_length();
		this->serial::Serial::write(addr, size);
	}

	void write(PackageType type) {
		this->serial::Serial::write(reinterpret_cast<byte const *>(&type), sizeof(type));
	}

	~Serial() {
		this->close();
	}
};
