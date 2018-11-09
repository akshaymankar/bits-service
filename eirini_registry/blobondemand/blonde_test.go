package blobondemand_test

import (
	"bytes"
	"testing"

	"code.cloudfoundry.org/eirini/blobondemand"
)

func TestSaveLoad(t *testing.T) {
	store := blobondemand.NewInMemoryStore()
	key, _, err := store.Put(bytes.NewReader([]byte("here-is-some-content")))
	if err != nil {
		t.Fatal(err)
	}

	if key != "sha256:e0c6189f72b0e909e963116fb71625186098e75a843abffc6f7f5ab53df8cdd3" {
		t.Fatalf("expected key to match sha of content but was %s", key)
	}

	var buf bytes.Buffer
	if err = store.Get("sha256:e0c6189f72b0e909e963116fb71625186098e75a843abffc6f7f5ab53df8cdd3", &buf); err != nil {
		t.Fatal(err)
	}

	if buf.String() != "here-is-some-content" {
		t.Fatalf("expected to retrieve 'here-is-some-content' but was '%s'", buf.String())
	}

	keyForID, _, err := store.PutWithID("my-id", bytes.NewReader([]byte("here-is-some-content")))
	if err != nil {
		t.Fatal(err)
	}

	if keyForID != "sha256:e0c6189f72b0e909e963116fb71625186098e75a843abffc6f7f5ab53df8cdd3" {
		t.Fatalf("expected key to match sha of content but was %s", keyForID)
	}

	var bufForID bytes.Buffer
	if err := store.Get("my-id", &bufForID); err != nil {
		t.Fatal(err)
	}

	if bufForID.String() != "here-is-some-content" {
		t.Fatalf("expected to retrieve 'here-is-some-content' but was '%s'", bufForID.String())
	}
}
