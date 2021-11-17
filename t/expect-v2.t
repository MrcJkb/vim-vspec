#!/bin/bash

./t/check-vspec-result <(cat <<'END'
describe 'ExpectV2()'
  it 'succeeds if an actual value matches to an expected value'
    call ExpectV2('have to').To(Equal('have to'))
  end

  it 'fails if an actual value does not match to an expected value'
    call ExpectV2('should').To(Equal('Expect'))
  end

  it 'shows the line number in :it block if failed'
    let a = 'AAA'
    let b = 'bbb'
    call ExpectV2(a).To(Equal(b))
  end
end
END
) <(cat <<'END'
ok 1 - ExpectV2() succeeds if an actual value matches to an expected value
not ok 2 - ExpectV2() fails if an actual value does not match to an expected value
# call ExpectV2('should').To(Equal('Expect')) at line 1
#     Expected value: "Expect"
#       Actual value: "should"
not ok 3 - ExpectV2() shows the line number in :it block if failed
# call ExpectV2(a).To(Equal(b)) at line 3
#     Expected value: "bbb"
#       Actual value: "AAA"
1..3
END
)

# vim: filetype=sh
