FLUTTER := fvm flutter

.PHONY: test test-update-goldens analyze get

## Run every test (unit, widget, golden) in test/.
test:
	$(FLUTTER) test

## Re-run the suite and regenerate golden baselines under test/**/*.png.
gen-goldens:
	$(FLUTTER) test --update-goldens

## Static analysis for the package and its example.
analyze:
	$(FLUTTER) analyze

## Fetch dependencies for the package and its example.
get:
	$(FLUTTER) pub get
