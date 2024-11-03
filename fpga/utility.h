#pragma once
#include <cstdint>
#include <format>
#include <iostream>
#include <serial/serial.h>
#include <stdexcept>

using byte = std::uint8_t;
using hword = std::uint16_t;
using dword = std::uint32_t;


namespace debug {

const char RESET[] = "\033[0m", RED[] = "\033[31m", BLUE[] = "\033[34m";

template<typename... Args>
void info(std::format_string<Args...> fmt, Args &&...args) {
	std::cerr << BLUE << std::format(fmt, std::forward<Args>(args)...) << RESET << std::flush;
}

template<typename... Args>
void error(std::format_string<Args...> fmt, Args &&...args) {
	std::cerr << RED << std::format(fmt, std::forward<Args>(args)...) << RESET << std::flush;
}

template<typename... Args>
void assert(bool cond, std::format_string<Args...> fmt, Args &&...args) {
	if (cond) return;
	throw std::runtime_error("Assertion Failed: " + std::format(fmt, std::forward<Args>(args)...));
}

} // namespace debug

using debug::error, debug::info, debug::assert;
