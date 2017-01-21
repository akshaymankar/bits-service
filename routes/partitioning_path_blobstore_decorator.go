package routes

import (
	"fmt"
	"io"
)

func DecorateWithPartitioningPathBlobstore(delegate Blobstore) *PartitioningPathBlobstoreDecorator {
	return &PartitioningPathBlobstoreDecorator{delegate}
}

type PartitioningPathBlobstoreDecorator struct {
	delegate Blobstore
}

func (decorator *PartitioningPathBlobstoreDecorator) Get(path string) (body io.ReadCloser, redirectLocation string, err error) {
	return decorator.delegate.Get(pathFor(path))
}

func (decorator *PartitioningPathBlobstoreDecorator) Head(path string) (redirectLocation string, err error) {
	return decorator.delegate.Head(pathFor(path))
}

func (decorator *PartitioningPathBlobstoreDecorator) Put(path string, src io.ReadSeeker) (redirectLocation string, err error) {
	return decorator.delegate.Put(pathFor(path), src)
}

func (decorator *PartitioningPathBlobstoreDecorator) Copy(src, dest string) (redirectLocation string, err error) {
	return decorator.delegate.Copy(pathFor(src), pathFor(dest))
}

func (decorator *PartitioningPathBlobstoreDecorator) Exists(path string) (bool, error) {
	return decorator.delegate.Exists(pathFor(path))
}

func (decorator *PartitioningPathBlobstoreDecorator) Delete(path string) error {
	return decorator.delegate.Delete(pathFor(path))
}

func (decorator *PartitioningPathBlobstoreDecorator) DeletePrefix(prefix string) error {
	if prefix == "" {
		return decorator.delegate.DeletePrefix(prefix)
	} else {
		return decorator.delegate.DeletePrefix(pathFor(prefix))
	}
}

func pathFor(identifier string) string {
	if len(identifier) >= 4 {
		return fmt.Sprintf("%s/%s/%s", identifier[0:2], identifier[2:4], identifier)
	} else if len(identifier) == 3 {
		return fmt.Sprintf("%s/%s/%s", identifier[0:2], identifier[2:3], identifier)
	} else if len(identifier) == 2 {
		return fmt.Sprintf("%s/%s", identifier[0:2], identifier)
	} else if len(identifier) == 1 {
		return fmt.Sprintf("%s/%s", identifier[0:1], identifier)
	}
	return ""
}

func DecorateWithPartitioningPathResourceSigner(delegate ResourceSigner) *PartitioningPathResourceSigner {
	return &PartitioningPathResourceSigner{delegate}
}

type PartitioningPathResourceSigner struct {
	delegate ResourceSigner
}

func (signer *PartitioningPathResourceSigner) Sign(resource string, method string) (signedURL string) {
	return signer.delegate.Sign(pathFor(resource), method)
}
