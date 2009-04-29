class Any is also {
    our Int multi method ceiling() is export {
        Q:PIR {
            $N0 = self
            $I0 = ceil $N0
            %r = box $I0
        }
    }

    our Str multi method chr() is export {
        Q:PIR {
            $I0 = self
            $S0 = chr $I0
            %r = box $S0
        }
    }

    our Complex multi method cis() is export {
        (1.0).unpolar(self)
    }

    our Int multi method floor() is export {
        Q:PIR {
            $N0 = self
            $I0 = floor $N0
            %r = box $I0
        }
    }

    our Num method rand() {
        Q:PIR {
            $N0 = self
            $P0 = get_hll_global ['Any'], '$!random'
            $N1 = $P0
            $N0 *= $N1
            %r = box $N0
        }
    }

    our Int multi method round() is export {
        Q:PIR {
            $N0 = self
            $N0 = $N0 + 0.5
            $I0 = floor $N0
            %r = box $I0
        }
    }

    # Used by the :Trig subs and methods in the Int and Num classes.
    our Int multi method !to-radians($base) {
        given $base {
            when /:i ^d/ { self * pi/180 }    # Convert from degrees.
            when /:i ^g/ { self * pi/200 }    # Convert from gradians.
            when /:i ^r/ { self }             # Convert from radians.
            when Num     { self * 2 * pi }    # Convert from revolutions.
            default { die "Unable to convert to base: $base" }
        }
    }

    our Int multi method !from-radians(Num $x, $base) {
        given $base {
            when /:i ^d/ { $x * 180/pi  }    # Convert to degrees.
            when /:i ^g/ { $x * 200/pi  }    # Convert to gradians.
            when /:i ^r/ { $x }              # Convert to radians.
            when Num     { $x /(2 * pi) }    # Convert to revolutions.
            default { die "Unable to convert to base: $base" }
        }
    }
}

our Int sub rand (*@args) {
    die "too many arguments passed - 0 params expected" if @args;
    1.rand
}
