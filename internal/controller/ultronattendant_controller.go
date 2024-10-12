/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	ultronv1alpha1 "github.com/be-heroes/ultron-operator/api/v1alpha1"
)

type UltronAttendantReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *UltronAttendantReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&ultronv1alpha1.UltronAttendant{}).
		Owns(&corev1.Pod{}).
		Complete(r)
}

// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultronattendants,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultronattendants/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultronattendants/finalizers,verbs=update
func (r *UltronAttendantReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	logger.Info("Reconciling UltronAttendant object")

	attendant := &ultronv1alpha1.UltronAttendant{}
	err := r.Client.Get(ctx, req.NamespacedName, attendant)

	if err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}

		return ctrl.Result{}, err
	}

	pod := newPodForUltronAttendant(attendant)

	if err := controllerutil.SetControllerReference(attendant, pod, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	foundPod := &corev1.Pod{}
	err = r.Client.Get(ctx, types.NamespacedName{Name: pod.Name, Namespace: pod.Namespace}, foundPod)

	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating a new Pod", "Pod.Namespace", pod.Namespace, "Pod.Name", pod.Name)

		err = r.Client.Create(ctx, pod)

		if err != nil {
			return ctrl.Result{}, err
		}

		return ctrl.Result{}, nil
	} else if err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func newPodForUltronAttendant(cr *ultronv1alpha1.UltronAttendant) *corev1.Pod {
	labels := map[string]string{
		"app": cr.Name,
	}

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name,
			Namespace: cr.Namespace,
			Labels:    labels,
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{cr.Spec.Container},
		},
	}

	return pod
}
