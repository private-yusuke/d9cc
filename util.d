module util;

public:

int nextInt(string s, ref size_t i)
{
    int res;
    while (i < s.length && '0' <= s[i] && s[i] <= '9')
    {
        res = (res * 10) + (s[i] - '0');
        i++;
    }
    return res;
}

class QuitException : Exception
{
    int return_code;

    this(int return_code = 0, string file = __FILE__, size_t line = __LINE__)
    {
        super(null, file, line);
        this.return_code = return_code;
    }
}
