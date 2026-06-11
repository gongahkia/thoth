#include "app_internal.hpp"

int main(int argc, char** argv)
{
    const int commandLineExit = thoth::app::runCommandLineMode(argc, argv);
    if (commandLineExit >= 0) {
        return commandLineExit;
    }

    return thoth::app::runInteractiveApp();
}
