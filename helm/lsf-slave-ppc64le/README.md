# LSF slave: This is LSF slave ppc64le chart

The chart installs a LSF slave node according to the following
pattern:

- A `Deployment` is used to create a Replica Set of lsf slave pods.
  ([templates/deployment.yaml](templates/deployment.yaml))

The [values.yaml](values.yaml) exposes a few of the configuration options in the
charts, though there are some that are not exposed there.