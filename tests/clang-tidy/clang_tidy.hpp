#pragma once

namespace my {

enum class usual_enum
{
	enumerator = 0,
};

enum class _impl_enum
{
	enumerator = 0,
};

inline constexpr int usual_constant = 0;
inline constexpr int _impl_constant = 0;

inline int g_global_variable;
inline thread_local int tls_thread_local_variable;

struct usual_struct
{
	static constexpr bool constant = false;
	int non_static_member_variable;
};

struct _impl_struct
{
};

class usual_class
{
	static constexpr bool usual_constant = false;
	static constexpr bool _impl_constant = false;

	static int s_static_member_variable;

	int m_non_static_member_variable = 0;

public:
	[[nodiscard]] int usual_member_function()
	{
		return _get_static_member_variable() + _get_non_static_member_variable();
	}

private:
	[[nodiscard]] static int _get_static_member_variable()
	{
		return s_static_member_variable;
	}

	[[nodiscard]] int _get_non_static_member_variable() const
	{
		return m_non_static_member_variable;
	}
};

class _impl_class
{
};

using usual_alias = usual_class;
using _impl_alias = _impl_class;

} // namespace my