// Copyright 2024 The Knative Authors
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"bufio"
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	utilyaml "k8s.io/apimachinery/pkg/util/yaml"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	"sigs.k8s.io/yaml"
)

var input = flag.String("backup-file", "", "backup file to restore")

func main() {
	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err)
	}

	client, err := dynamic.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	yamlInput, err := os.ReadFile(*input)
	if err != nil {
		panic(err)
	}

	multidocReader := utilyaml.NewYAMLReader(bufio.NewReader(bytes.NewReader(yamlInput)))
	for {
		buf, err := multidocReader.Read()
		if err != nil {
			if err == io.EOF {
				break
			}
		}
		// Define the unstructured object into which the YAML document will be
		// unmarshaled.
		list := &unstructured.UnstructuredList{}

		// Unmarshal the YAML document into the unstructured object.
		if err := yaml.Unmarshal(buf, &list); err != nil {
			panic(err)
		}

		for _, obj := range list.Items {
			obj := obj
			sanitizeObj(client, &obj)

			resource := gvrFromAPIVersion(obj.GetAPIVersion(), obj.GetKind())

			var rClient dynamic.ResourceInterface
			if obj.GetNamespace() != "" {
				rClient = client.Resource(resource).Namespace(obj.GetNamespace())
			} else {
				rClient = client.Resource(resource)
			}

			fmt.Printf("Creating resource %q %s/%s\n", resource, obj.GetNamespace(), obj.GetName())
			val, err := rClient.Create(context.Background(), &obj, metav1.CreateOptions{})
			if err != nil {
				panic(err)
			}

			if obj.GetKind() == "ConfigMap" {
				continue
			}

			obj.SetResourceVersion(val.GetResourceVersion())
			fmt.Printf("Update resource status %q %s/%s\n", resource, obj.GetNamespace(), obj.GetName())
			_, err = rClient.UpdateStatus(context.Background(), &obj, metav1.UpdateOptions{})
			if err != nil {
				panic(err)
			}
		}
	}
}

func sanitizeObj(client *dynamic.DynamicClient, u *unstructured.Unstructured) {
	unstructured.RemoveNestedField(u.Object, "metadata", "resourceVersion")
	unstructured.RemoveNestedField(u.Object, "metadata", "uid")

	// Restore owner reference uid
	refs := u.GetOwnerReferences()
	for i, ref := range refs {
		if ref.UID == "" {
			gvr := gvrFromAPIVersion(ref.APIVersion, ref.Kind)
			owner, err := client.Resource(gvr).Namespace(u.GetNamespace()).Get(context.TODO(), ref.Name, metav1.GetOptions{})
			if err != nil {
				panic(err)
			}
			ref.UID = owner.GetUID()
			refs[i] = ref
		}
	}
	u.SetOwnerReferences(refs)

	// Clear last apply annoation
	ann := u.GetAnnotations()
	delete(ann, " kubectl.kubernetes.io/last-applied-configuration")
	u.SetAnnotations(ann)
}

func gvrFromAPIVersion(apiVersion, kind string) schema.GroupVersionResource {
	gv, err := schema.ParseGroupVersion(apiVersion)
	if err != nil {
		panic(err)
	}
	// This is dumb pluralization
	resource := strings.ToLower(kind)
	if strings.HasSuffix(resource, "s") {
		resource += "es"
	} else {
		resource += "s"
	}
	return gv.WithResource(resource)
}
