class Object is also {
    multi method perl {
        self.WHAT.substr(0, -2) ~ '.new()';
    }

    multi method eigenstates {
        list(self)
    }
}

# vim: ft=perl6
