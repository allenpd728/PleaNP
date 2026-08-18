-- Mock case 3: a custom axiom declaration. Always a VIOLATION — proves
-- nothing, just declares. The scan must flag `axiom` as a declaration.

namespace PleaNP

-- smuggled: declare a custom axiom, then "prove" using it
axiom FakeAssumption : True

theorem fake_success : True := FakeAssumption

end PleaNP
