using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LineController : MonoBehaviour
{

    private LineRenderer lr;
    private Vector3[] points;

    // Start is called before the first frame update
    private void Awake()
    {
        lr = GetComponent<LineRenderer>();
    }

    public void SetUpLine(Vector3[] points)
    {
        lr.positionCount = points.Length;
        this.points = points;
    }

    // Update is called once per frame
    private void Update()
    {
        if (points != null)
        {
            for (int i = 0; i < points.Length; i++)
            {
                lr.SetPosition(i, points[i]);
            }
        }
       
    }
}
