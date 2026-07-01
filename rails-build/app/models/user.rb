class User < ApplicationRecord
  # Exercises the bcrypt C extension that JOBS compiles from source with zig cc.
  has_secure_password
end
