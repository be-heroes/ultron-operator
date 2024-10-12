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
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	ultronv1alpha1 "github.com/be-heroes/ultron-operator/api/v1alpha1"
)

type UltronReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *UltronReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&ultronv1alpha1.Ultron{}).
		Owns(&corev1.Pod{}).
		Owns(&corev1.Service{}).
		Complete(r)
}

// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultrons,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultrons/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=ultron.2mind.dk,resources=ultrons/finalizers,verbs=update
func (r *UltronReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	logger.Info("Reconciling Ultron object")

	ultron := &ultronv1alpha1.Ultron{}
	err := r.Client.Get(ctx, req.NamespacedName, ultron)

	if err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}

		return ctrl.Result{}, err
	}

	pod := newPodForUltron(ultron)

	if err := controllerutil.SetControllerReference(ultron, pod, r.Scheme); err != nil {
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

	service := newServiceForUltron(ultron)

	if err := controllerutil.SetControllerReference(ultron, service, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	foundService := &corev1.Service{}
	err = r.Client.Get(ctx, types.NamespacedName{Name: service.Name, Namespace: service.Namespace}, foundService)

	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating a new Service", "Service.Namespace", service.Namespace, "Service.Name", service.Name)

		err = r.Client.Create(ctx, service)

		if err != nil {
			return ctrl.Result{}, err
		}

		return ctrl.Result{}, nil
	} else if err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func newPodForUltron(cr *ultronv1alpha1.Ultron) *corev1.Pod {
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

	if (cr.Spec.DataVolume != corev1.Volume{}) {
		pod.Spec.Volumes = []corev1.Volume{cr.Spec.DataVolume}
		pod.Spec.Containers[0].VolumeMounts = []corev1.VolumeMount{
			{
				Name:      cr.Spec.DataVolume.Name,
				MountPath: "/ultron-volume",
			},
		}
	}

	return pod
}

func newServiceForUltron(cr *ultronv1alpha1.Ultron) *corev1.Service {
	labels := map[string]string{
		"app": cr.Name,
	}

	selector := map[string]string{
		"app": cr.Name,
	}

	ports := []corev1.ServicePort{
		{
			Name:       "https",
			Port:       8443,
			TargetPort: intstr.FromString("https"),
		},
	}

	return &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cr.Name,
			Namespace: cr.Namespace,
			Labels:    labels,
		},
		Spec: corev1.ServiceSpec{
			Ports:    ports,
			Selector: selector,
		},
	}
}
